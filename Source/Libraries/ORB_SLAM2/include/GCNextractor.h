/**
 * This file is part of ORB-SLAM2.
 *
 * Minimal LibTorch-2.8 port for GCNextractor, aligned with SuperPoint style.
 * Keeps fixed-resolution preprocessing, ratio-based coordinate upscale,
 * and 32xU8 descriptor format.
 */

#ifndef GCNEXTRACTOR_H
#define GCNEXTRACTOR_H

#include "FeatureExtractor.h"

#include <torch/script.h>
#include <torch/torch.h>
#include <memory>
#include <string>

namespace ORB_SLAM2 {

class GCNextractor : public FeatureExtractor {
public:
  // Legacy-style constructor (kept for backward compatibility)
  GCNextractor(int nfeatures, float scaleFactor, int nlevels,
               int iniThFAST, int minThFAST);

  // Factory-style constructor (like SuperPointExtractor)
  GCNextractor(const cv::FileNode& cfg, bool init);

  virtual ~GCNextractor() {}

  // Compute features and descriptors on an image (mask ignored).
  void operator()(cv::InputArray image, cv::InputArray mask,
                  std::vector<cv::KeyPoint> &keypoints,
                  cv::OutputArray descriptors) override;

  // Print runtime/config info (required by base class)
  void InfoConfigs() override;

  // Ensure linker pulls this TU when using the factory
  static void ForceLinking();

protected:
  std::shared_ptr<torch::jit::script::Module> module;

  // Runtime/options
  bool        mUseCUDA   = false;
  int         mInputW    = 320;
  int         mInputH    = 240;
  int         mBorder    = 8;
  int         mDistTh    = 4;
  std::string mWeightsPath;
  torch::Device mDevice  = torch::kCPU;
};

} // namespace ORB_SLAM2

#endif // GCNEXTRACTOR_H
