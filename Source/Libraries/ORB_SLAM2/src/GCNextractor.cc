/**
 * This file is part of ORB-SLAM2.
 *
 * Minimal LibTorch-2.8 port for GCNextractor, aligned with SuperPoint style.
 * - New API: NoGradGuard, module->eval(), .to(device), from_blob(...).clone()
 * - Factory registration with ForceLinking(), "GCN" name
 * - Preserves fixed-resolution inference and ratio upscaling of coordinates
 * - Keeps 32xU8 descriptor matrix, similar to original GCN path
 */

#include "GCNextractor.h"
#include "FeatureExtractorFactory.h"

#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>

#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <vector>

#include <iomanip>

using namespace std;
using namespace cv;

namespace ORB_SLAM2 {

/** ------------------------------------------------------------------------
 * Simple NMS with square neighborhood suppression.
 * pts:  Nx3 float [u, v, score]
 * desc: Nx32 uint8
 * Output keypoints are scaled back to original image size via ratio_w/ratio_h.
 * ------------------------------------------------------------------------- */
static void nms(const cv::Mat& pts, const cv::Mat& desc,
                std::vector<cv::KeyPoint>& keypoints, cv::Mat& descriptors,
                int border, int dist_thresh,
                int img_w, int img_h,
                float ratio_w, float ratio_h)
{
  CV_Assert(pts.type() == CV_32FC1 && pts.cols == 3);
  CV_Assert(desc.type() == CV_8UC1 && desc.cols == 32);
  const int N = pts.rows;
  if (N <= 0) {
    keypoints.clear();
    descriptors.release();
    return;
  }

  // Collect valid indices inside border
  std::vector<int> valid;
  valid.reserve(N);
  for (int i = 0; i < N; ++i) {
    const float u = pts.at<float>(i, 0);
    const float v = pts.at<float>(i, 1);
    if (u >= border && u < img_w - border &&
        v >= border && v < img_h - border)
    {
      valid.push_back(i);
    }
  }
  if (valid.empty()) {
    keypoints.clear();
    descriptors.release();
    return;
  }

  // Sort by score descending
  std::sort(valid.begin(), valid.end(), [&](int a, int b){
    const float sa = pts.at<float>(a, 2);
    const float sb = pts.at<float>(b, 2);
    return sa > sb;
  });

  const int r = std::max(1, dist_thresh);
  const int r2 = r * r;

  // Greedy NMS
  std::vector<char> suppressed(N, 0);
  std::vector<int> picked; picked.reserve(valid.size());

  for (int idx : valid) {
    if (suppressed[idx]) continue;
    picked.push_back(idx);

    const float ux = pts.at<float>(idx, 0);
    const float uy = pts.at<float>(idx, 1);

    for (int jdx : valid) {
      if (suppressed[jdx] || jdx == idx) continue;
      const float vx = pts.at<float>(jdx, 0);
      const float vy = pts.at<float>(jdx, 1);
      const float dx = ux - vx;
      const float dy = uy - vy;
      if (dx*dx + dy*dy <= r2) suppressed[jdx] = 1;
    }
  }

  const int M = static_cast<int>(picked.size());
  keypoints.clear(); keypoints.reserve(M);
  descriptors.create(M, 32, CV_8U);

  for (int i = 0; i < M; ++i) {
    const int idx = picked[i];
    const float u = pts.at<float>(idx, 0) * ratio_w;
    const float v = pts.at<float>(idx, 1) * ratio_h;
    const float sc = pts.at<float>(idx, 2);

    cv::KeyPoint kp;
    kp.pt       = cv::Point2f(u, v);
    kp.size     = 7.f;
    kp.angle    = -1.f;
    kp.response = sc;
    kp.octave   = 0;
    kp.class_id = -1;
    keypoints.emplace_back(kp);

    // copy descriptor row (32 bytes)
    const uchar* src = desc.ptr<uchar>(idx);
    uchar* dst = descriptors.ptr<uchar>(i);
    std::memcpy(dst, src, 32);
  }
}



GCNextractor::GCNextractor(int _nfeatures, float _scaleFactor, int _nlevels,
                           int _iniThFAST, int _minThFAST)
  : FeatureExtractor(_nfeatures, _scaleFactor, _nlevels, _iniThFAST, _minThFAST)
{
  mUseCUDA = torch::cuda::is_available();

  // Default fixed-resolution policy follows your original logic:
  if (std::getenv("FULL_RESOLUTION") != nullptr) {
    mInputW = 640; mInputH = 480; mBorder = 16; mDistTh = 8;
  } else {
    mInputW = 320; mInputH = 240; mBorder = 8;  mDistTh = 4;
  }

  const char* env_weights = std::getenv("GCN_PATH");
  if (env_weights) mWeightsPath = env_weights;

  if (mWeightsPath.empty()) {
    // Backward-compatible fallback names
    if (mUseCUDA) {
      mWeightsPath = (mInputW >= 640) ? "gcn2_640x480.pt" : "gcn2_320x240.pt";
    } else {
      mWeightsPath = (mInputW >= 640) ? "gcn2_640x480_cpu.pt" : "gcn2_320x240_cpu.pt";
    }
  }

  mDevice = mUseCUDA ? torch::Device(torch::kCUDA) : torch::Device(torch::kCPU);
  std::cout << "[GCN] Loading model: " << mWeightsPath << std::endl;

  module = std::make_shared<torch::jit::script::Module>(torch::jit::load(mWeightsPath));
  module->eval();
  module->to(mDevice);

  std::cout << "[GCN] Loaded on device: " << (mUseCUDA ? "CUDA" : "CPU") << std::endl;
}

GCNextractor::GCNextractor(const cv::FileNode& cfg, bool init)
  : FeatureExtractor(cfg, init)
{
  mUseCUDA     = cfg["use_cuda"].empty()      ? torch::cuda::is_available()
                                              : ((int)cfg["use_cuda"] != 0);
  mWeightsPath = cfg["weights"].empty()       ? std::string() : (std::string)cfg["weights"];
  mInputW      = cfg["input_width"].empty()   ? 320 : (int)cfg["input_width"];
  mInputH      = cfg["input_height"].empty()  ? 240 : (int)cfg["input_height"];

  if (mInputW >= 640) { mBorder = 16; mDistTh = 8; } else { mBorder = 8; mDistTh = 4; }

  if (mWeightsPath.empty()) {
    if (const char* env = std::getenv("GCN_PATH")) mWeightsPath = env;
  }
  if (mWeightsPath.empty()) {
    if (mUseCUDA) {
      mWeightsPath = (mInputW >= 640) ? "gcn2_640x480.pt" : "gcn2_320x240.pt";
    } else {
      mWeightsPath = (mInputW >= 640) ? "gcn2_640x480_cpu.pt" : "gcn2_320x240_cpu.pt";
    }
  }

  mDevice = mUseCUDA ? torch::Device(torch::kCUDA) : torch::Device(torch::kCPU);
  std::cout << "[GCN] Loading model: " << mWeightsPath << std::endl;

  module = std::make_shared<torch::jit::script::Module>(torch::jit::load(mWeightsPath));
  module->eval();
  module->to(mDevice);

  std::cout << "[GCN] Loaded on device: " << (mUseCUDA ? "CUDA" : "CPU") << std::endl;
}



void GCNextractor::operator()(cv::InputArray _image, cv::InputArray _mask,
                              std::vector<cv::KeyPoint> &_keypoints,
                              cv::OutputArray _descriptors)
{
  torch::NoGradGuard _no_grad;

  if (_image.empty()) return;

  cv::Mat image = _image.getMat();
  CV_Assert(image.type() == CV_8UC1);


  cv::Mat img_f32;
  image.convertTo(img_f32, CV_32FC1, 1.f/255.f);
  const int net_w = mInputW, net_h = mInputH;

  const float ratio_w = static_cast<float>(image.cols) / static_cast<float>(net_w);
  const float ratio_h = static_cast<float>(image.rows) / static_cast<float>(net_h);

  cv::resize(img_f32, img_f32, cv::Size(net_w, net_h), 0, 0, cv::INTER_LINEAR);


  auto tensor = torch::from_blob(
      img_f32.ptr<float>(),
      {1, 1, net_h, net_w},
      torch::TensorOptions().dtype(torch::kFloat32)
  ).clone().to(mDevice);

  std::vector<torch::jit::IValue> inputs;
  inputs.emplace_back(tensor);


  auto outTuple = module->forward(inputs).toTuple();


  auto pts  = outTuple->elements()[0].toTensor().to(torch::kCPU).contiguous().squeeze();
  auto desc = outTuple->elements()[1].toTensor().to(torch::kCPU).contiguous().squeeze();


auto P = pts.to(torch::kCPU).contiguous();
auto P0 = P.index({torch::indexing::Slice(), 0});
auto P1 = P.index({torch::indexing::Slice(), 1});
auto P2 = P.index({torch::indexing::Slice(), 2});
auto stats = [](const torch::Tensor& t){
    auto mn = t.min().item<float>();
    auto mx = t.max().item<float>();
    auto me = t.mean().item<float>();
    std::cout << "min=" << mn << " max=" << mx << " mean=" << me;
};

std::cout << "[GCN] RAW col0: "; stats(P0); std::cout << std::endl;
std::cout << "[GCN] RAW col1: "; stats(P1); std::cout << std::endl;
std::cout << "[GCN] RAW col2: "; stats(P2); std::cout << std::endl;


const int64_t n_pts       = pts.size(0);
const int64_t n_desc_rows = desc.size(0);
const int64_t n_desc_cols = desc.size(1);



// Detect coordinate range to guess normalization
auto pts_cpu = pts.to(torch::kCPU).contiguous();
auto u = pts_cpu.index({torch::indexing::Slice(), 0});
auto v = pts_cpu.index({torch::indexing::Slice(), 1});

float u_min = u.min().item<float>(), u_max = u.max().item<float>();
float v_min = v.min().item<float>(), v_max = v.max().item<float>();

bool looks_01 = (u_min >= -1.01f && u_max <= 1.01f &&
                 v_min >= -1.01f && v_max <= 1.01f);

bool looks_m11 = (u_min < 0.0f || v_min < 0.0f);

if (looks_01) {
  if (looks_m11) {

    pts_cpu.index_put_({torch::indexing::Slice(), 0},
      (u * 0.5f + 0.5f) * net_w);
    pts_cpu.index_put_({torch::indexing::Slice(), 1},
      (v * 0.5f + 0.5f) * net_h);
  } else {

    pts_cpu.index_put_({torch::indexing::Slice(), 0}, u * net_w);
    pts_cpu.index_put_({torch::indexing::Slice(), 1}, v * net_h);
  }
  pts = pts_cpu;
}

std::cout << "[GCN] model output — pts: " << n_pts
          << ", desc: " << n_desc_rows << " x " << n_desc_cols << std::endl;

if (n_pts != n_desc_rows) {
  std::cout << "[GCN][WARN] pts rows != desc rows ("
            << n_pts << " vs " << n_desc_rows << ")" << std::endl;
}


  CV_Assert(pts.dim() == 2 && pts.size(1) == 3);
  CV_Assert(desc.dim() == 2 && desc.size(1) == 32);



  // Map to cv::Mat then clone to own memory (avoid dangling pointers)
  cv::Mat pts_mat (cv::Size(3,  pts.size(0)), CV_32FC1,  pts.data_ptr<float>());
  cv::Mat desc_mat(cv::Size(32, pts.size(0)), CV_8UC1,   desc.data_ptr<uint8_t>());
  pts_mat  = pts_mat.clone();
  desc_mat = desc_mat.clone();


std::vector<cv::KeyPoint> keypoints;
cv::Mat descriptors;


const int N = pts_mat.rows;
std::vector<int> idx(N);
std::iota(idx.begin(), idx.end(), 0);
std::stable_sort(idx.begin(), idx.end(), [&](int a, int b){
  return pts_mat.at<float>(a, 2) > pts_mat.at<float>(b, 2);
});


int K = N;

keypoints.reserve(K);
descriptors.create(K, 32, CV_8U);

for (int j = 0; j < K; ++j) {
  const int i = idx[j];
  const float u = pts_mat.at<float>(i, 0) * ratio_w;
  const float v = pts_mat.at<float>(i, 1) * ratio_h;
  const float sc = pts_mat.at<float>(i, 2);

  cv::KeyPoint kp;
  kp.pt       = cv::Point2f(u, v);
  kp.size     = 7.f;
  kp.angle    = -1.f;
  kp.response = sc;
  kp.octave   = 0;
  kp.class_id = -1;
  keypoints.emplace_back(kp);

  std::memcpy(descriptors.ptr<uchar>(j),
              desc_mat.ptr<uchar>(i), 32);
}
int W = image.cols, H = image.rows;
int in_bounds = 0;
for (const auto& kp : keypoints) {
  if (kp.pt.x >= 0 && kp.pt.x < W && kp.pt.y >= 0 && kp.pt.y < H) ++in_bounds;
}
std::cout << "[GCN] in-bounds keypoints: " << in_bounds << " / " << keypoints.size() << std::endl;


_keypoints.insert(_keypoints.end(), keypoints.begin(), keypoints.end());
_descriptors.create(K, 32, CV_8U);
if (K > 0) descriptors.copyTo(_descriptors.getMat());

std::cout << "[GCN] raw(out) — keypoints: " << K
          << ", descriptors: " << descriptors.rows << " x " << descriptors.cols
          << std::endl;


std::cout << "[GCN] image size: " << image.cols << "x" << image.rows << std::endl;

std::cout.setf(std::ios::fixed);
std::cout << std::setprecision(2);

int nprint = std::min<int>(5000, keypoints.size());
for (int i = 0; i < nprint; ++i) {
    const auto& kp = keypoints[i];
    std::cout << "[GCN] kp[" << i << "]: x=" << kp.pt.x
              << ", y=" << kp.pt.y
              << ", score=" << kp.response << std::endl;
}
}

void GCNextractor::InfoConfigs() {
  std::cout << "[GCN] nFeatures=" << nfeatures
            << " nLevels=" << nlevels
            << " scaleFactor=" << static_cast<float>(scaleFactor)
            << " use_cuda=" << (mUseCUDA ? 1 : 0)
            << " input=" << mInputW << "x" << mInputH
            << " border=" << mBorder
            << " nms=" << mDistTh
            << " weights=" << (mWeightsPath.empty() ? "(default)" : mWeightsPath)
            << std::endl;
}

void GCNextractor::ForceLinking() {}

} // namespace ORB_SLAM2

namespace {
struct GCNRegister {
  GCNRegister() {
    std::cout << "Registering GCNextractor..." << std::endl;
    ORB_SLAM2::FeatureExtractorFactory::Instance().Register(
      "GCN",
      [](const cv::FileNode& cfg, const bool init) -> ORB_SLAM2::FeatureExtractor* {
        return new ORB_SLAM2::GCNextractor(cfg, init);
      }
    );
  }
};
static GCNRegister g_GCNRegisterInstance;
} // anonymous namespace
