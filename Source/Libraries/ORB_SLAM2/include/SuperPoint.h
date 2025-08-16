/**
 * >>> This is modified version of original SuperSLAM::SuperPoint <<<
 *  By Howard Cui <haoyangcui at outlook dot com>
 *
 * This file is part of SuperSLAM.
 *
 * Copyright (C) Aditya Wagh <adityamwagh at outlook dot com>
 * For more information see <https://github.com/adityamwagh/SuperSLAM>
 *
 * SuperSLAM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * SuperSLAM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with SuperSLAM. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef SUPERPOINT_H
#define SUPERPOINT_H

#include <torch/torch.h>

#include <opencv2/opencv.hpp>
#include <vector>

#ifdef EIGEN_MPL2_ONLY
#undef EIGEN_MPL2_ONLY
#endif

namespace SuperSLAM {

struct SuperPoint : torch::nn::Module {
  SuperPoint();

  std::vector<torch::Tensor> forward(torch::Tensor x);

  torch::nn::Conv2d conv1a;
  torch::nn::Conv2d conv1b;

  torch::nn::Conv2d conv2a;
  torch::nn::Conv2d conv2b;

  torch::nn::Conv2d conv3a;
  torch::nn::Conv2d conv3b;

  torch::nn::Conv2d conv4a;
  torch::nn::Conv2d conv4b;

  torch::nn::Conv2d convPa;
  torch::nn::Conv2d convPb;

  // descriptor
  torch::nn::Conv2d convDa;
  torch::nn::Conv2d convDb;
};

// cv::Mat SPdetect(std::shared_ptr<SuperPoint> model, cv::Mat img,
// std::vector<cv::KeyPoint> &keypoints, double threshold, bool nms, bool cuda);
//  torch::Tensor NMS(torch::Tensor kpts);

class SPDetector {
 public:
  SPDetector(std::shared_ptr<SuperPoint> _model, bool cuda);
  void detect(cv::Mat& image);
  void getKeyPoints(float threshold, int iniX, int maxX, int iniY, int maxY,
                    std::vector<cv::KeyPoint>& keypoints, bool nms);
  void computeDescriptors(const std::vector<cv::KeyPoint>& keypoints,
                          cv::Mat& descriptors);

 private:
  std::shared_ptr<SuperPoint> model;
  torch::Tensor mProb;
  torch::Tensor mDesc;
  torch::DeviceType m_device;
};

}  // namespace SuperSLAM

#endif
