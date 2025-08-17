/**
 * >>> This is modified version of original SuperSLAM::SPextractor <<<
 *  By Howard Cui <haoyangcui at outlook dot com>
 *
 * This file is part of SuperSLAM.
 * This file is based on the file orb.cpp from the OpenCV library (see BSD
 * license below).
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
/**
 * Software License Agreement (BSD License)
 *
 *  Copyright (c) 2009, Willow Garage, Inc.
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above
 *     copyright notice, this list of conditions and the following
 *     disclaimer in the documentation and/or other materials provided
 *     with the distribution.
 *   * Neither the name of the Willow Garage nor the names of its
 *     contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "SuperPointExtractor.h"

#include <opencv2/imgproc.hpp>
#include <torch/torch.h>
#include <algorithm>
#include <iostream>
#include <stdexcept>

namespace ORB_SLAM2 {

using SuperSLAM::SPDetector;

SuperPointExtractor::SuperPointExtractor(const cv::FileNode& cfg, bool init)
    : FeatureExtractor(cfg, init)
{
    mIniThFAST = !cfg["iniThFAST"].empty() ? float(cfg["iniThFAST"])
                  : (!cfg["iniTh"].empty() ? float(cfg["iniTh"]) : 0.4f);
    mMinThFAST = !cfg["minThFAST"].empty() ? float(cfg["minThFAST"])
                  : (!cfg["minTh"].empty() ? float(cfg["minTh"]) : 0.2f);
    mUseCUDA   = !cfg["use_cuda"].empty()  && int(cfg["use_cuda"]) != 0;
    mUseNMS    =  cfg["nms"].empty() ? true : (int(cfg["nms"]) != 0);
    if (!cfg["weights"].empty()) mWeightsPath = (std::string)cfg["weights"];

    mModel = std::make_shared<SuperSLAM::SuperPoint>();

    try {
        if (!mWeightsPath.empty()) {
            try {
                torch::load(mModel, mWeightsPath);
            } catch (...) {
                torch::serialize::InputArchive ar;
                ar.load_from(mWeightsPath);
                mModel->load(ar);
            }
        } else {
            std::cerr << "[SuperPoint] WARNING: empty weights path; using random weights.\n";
        }
    } catch (const std::exception& e) {
        throw std::runtime_error(std::string("[SuperPoint] load weights failed: ") + e.what());
    }
    mModel->eval();
    if (mUseCUDA) mModel->to(torch::kCUDA);
}

void SuperPointExtractor::InfoConfigs() {
    std::cout << "- Number of Features: " << nfeatures << std::endl;
    std::cout << "- Scale Levels: " << nlevels << std::endl;
    std::cout << "- Scale Factor: " << scaleFactor << std::endl;
    std::cout << "- Use CUDA: " << mUseCUDA << std::endl;
    std::cout << "- Use NMS: " << mUseNMS << std::endl;
    std::cout << "- iniThFAST: " << mIniThFAST << std::endl;
    std::cout << "- minThFAST: " << mMinThFAST << std::endl;
}

void SuperPointExtractor::ExtractorNode::DivideNode(
    ExtractorNode& n1, ExtractorNode& n2, ExtractorNode& n3, ExtractorNode& n4)
{
    const int halfX = std::ceil(static_cast<float>(UR.x - UL.x) / 2.f);
    const int halfY = std::ceil(static_cast<float>(BR.y - UL.y) / 2.f);

    n1.UL = UL;
    n1.UR = cv::Point2i(UL.x + halfX, UL.y);
    n1.BL = cv::Point2i(UL.x, UL.y + halfY);
    n1.BR = cv::Point2i(UL.x + halfX, UL.y + halfY);
    n1.vKeys.reserve(vKeys.size());

    n2.UL = n1.UR;
    n2.UR = UR;
    n2.BL = n1.BR;
    n2.BR = cv::Point2i(UR.x, UL.y + halfY);
    n2.vKeys.reserve(vKeys.size());

    n3.UL = n1.BL;
    n3.UR = n1.BR;
    n3.BL = BL;
    n3.BR = cv::Point2i(n1.BR.x, BL.y);
    n3.vKeys.reserve(vKeys.size());

    n4.UL = n3.UR;
    n4.UR = n2.BR;
    n4.BL = n3.BR;
    n4.BR = BR;
    n4.vKeys.reserve(vKeys.size());

    for (const auto& kp : vKeys) {
        if (kp.pt.x < n1.UR.x) {
            if (kp.pt.y < n1.BR.y) n1.vKeys.push_back(kp);
            else                    n3.vKeys.push_back(kp);
        } else if (kp.pt.y < n1.BR.y) {
            n2.vKeys.push_back(kp);
        } else {
            n4.vKeys.push_back(kp);
        }
    }

    if (n1.vKeys.size() == 1) n1.bNoMore = true;
    if (n2.vKeys.size() == 1) n2.bNoMore = true;
    if (n3.vKeys.size() == 1) n3.bNoMore = true;
    if (n4.vKeys.size() == 1) n4.bNoMore = true;
}

std::vector<cv::KeyPoint> SuperPointExtractor::DistributeOctTree(
    const std::vector<cv::KeyPoint>& vToDistributeKeys, const int& minX,
    const int& maxX, const int& minY, const int& maxY, const int& N,
    const int& level)
{
    // Compute how many initial nodes
    int nIni = std::round(static_cast<float>(maxX - minX) / (maxY - minY));
    nIni = std::max(1, nIni);
    const float hX = static_cast<float>(maxX - minX) / nIni;

    std::list<ExtractorNode> lNodes;
    std::vector<ExtractorNode*> vpIniNodes(nIni);

    for (int i = 0; i < nIni; i++) {
        ExtractorNode ni;
        ni.UL = cv::Point2i(hX * static_cast<float>(i), 0);
        ni.UR = cv::Point2i(hX * static_cast<float>(i + 1), 0);
        ni.BL = cv::Point2i(ni.UL.x, maxY - minY);
        ni.BR = cv::Point2i(ni.UR.x, maxY - minY);
        ni.vKeys.reserve(vToDistributeKeys.size());
        lNodes.push_back(ni);
        vpIniNodes[i] = &lNodes.back();
    }

    for (const auto& kp : vToDistributeKeys) {
        int idx = std::min(int((kp.pt.x - minX) / hX), nIni - 1);
        idx = std::max(0, idx);
        vpIniNodes[idx]->vKeys.push_back(kp);
    }

    auto lit = lNodes.begin();
    while (lit != lNodes.end()) {
        if (lit->vKeys.size() == 1) { lit->bNoMore = true; ++lit; }
        else if (lit->vKeys.empty()) { lit = lNodes.erase(lit); }
        else { ++lit; }
    }

    bool bFinish = false;
    std::vector<std::pair<int, ExtractorNode*>> vSizeAndPointerToNode;
    vSizeAndPointerToNode.reserve(lNodes.size() * 4);

    while (!bFinish) {
        const int prevSize = (int)lNodes.size();
        lit = lNodes.begin();
        int nToExpand = 0;
        vSizeAndPointerToNode.clear();

        while (lit != lNodes.end()) {
            if (lit->bNoMore) { ++lit; continue; }

            ExtractorNode n1, n2, n3, n4;
            lit->DivideNode(n1, n2, n3, n4);

            if (!n1.vKeys.empty()) {
                lNodes.push_front(n1);
                if (n1.vKeys.size() > 1) {
                    nToExpand++;
                    vSizeAndPointerToNode.emplace_back((int)n1.vKeys.size(), &lNodes.front());
                    lNodes.front().lit = lNodes.begin();
                }
            }
            if (!n2.vKeys.empty()) {
                lNodes.push_front(n2);
                if (n2.vKeys.size() > 1) {
                    nToExpand++;
                    vSizeAndPointerToNode.emplace_back((int)n2.vKeys.size(), &lNodes.front());
                    lNodes.front().lit = lNodes.begin();
                }
            }
            if (!n3.vKeys.empty()) {
                lNodes.push_front(n3);
                if (n3.vKeys.size() > 1) {
                    nToExpand++;
                    vSizeAndPointerToNode.emplace_back((int)n3.vKeys.size(), &lNodes.front());
                    lNodes.front().lit = lNodes.begin();
                }
            }
            if (!n4.vKeys.empty()) {
                lNodes.push_front(n4);
                if (n4.vKeys.size() > 1) {
                    nToExpand++;
                    vSizeAndPointerToNode.emplace_back((int)n4.vKeys.size(), &lNodes.front());
                    lNodes.front().lit = lNodes.begin();
                }
            }

            lit = lNodes.erase(lit);
            if ((int)lNodes.size() >= N) break;
        }

        if ((int)lNodes.size() >= N || (int)lNodes.size() == prevSize) {
            bFinish = true;
        } else if (((int)lNodes.size() + nToExpand * 3) > N) {
            while (!bFinish) {
                int prevSize2 = (int)lNodes.size();
                auto vPrev = vSizeAndPointerToNode;
                vSizeAndPointerToNode.clear();

                std::sort(vPrev.begin(), vPrev.end());
                for (int j = (int)vPrev.size() - 1; j >= 0; --j) {
                    ExtractorNode n1, n2, n3, n4;
                    vPrev[j].second->DivideNode(n1, n2, n3, n4);

                    if (!n1.vKeys.empty()) {
                        lNodes.push_front(n1);
                        if (n1.vKeys.size() > 1) {
                            vSizeAndPointerToNode.emplace_back((int)n1.vKeys.size(), &lNodes.front());
                            lNodes.front().lit = lNodes.begin();
                        }
                    }
                    if (!n2.vKeys.empty()) {
                        lNodes.push_front(n2);
                        if (n2.vKeys.size() > 1) {
                            vSizeAndPointerToNode.emplace_back((int)n2.vKeys.size(), &lNodes.front());
                            lNodes.front().lit = lNodes.begin();
                        }
                    }
                    if (!n3.vKeys.empty()) {
                        lNodes.push_front(n3);
                        if (n3.vKeys.size() > 1) {
                            vSizeAndPointerToNode.emplace_back((int)n3.vKeys.size(), &lNodes.front());
                            lNodes.front().lit = lNodes.begin();
                        }
                    }
                    if (!n4.vKeys.empty()) {
                        lNodes.push_front(n4);
                        if (n4.vKeys.size() > 1) {
                            vSizeAndPointerToNode.emplace_back((int)n4.vKeys.size(), &lNodes.front());
                            lNodes.front().lit = lNodes.begin();
                        }
                    }

                    lNodes.erase(vPrev[j].second->lit);
                    if ((int)lNodes.size() >= N) break;
                }

                if ((int)lNodes.size() >= N || (int)lNodes.size() == prevSize2)
                    bFinish = true;
            }
        }
    }

    // Retain the best point in each node
    std::vector<cv::KeyPoint> vResultKeys;
    vResultKeys.reserve(N);
    for (auto it = lNodes.begin(); it != lNodes.end(); ++it) {
        auto& vNodeKeys = it->vKeys;
        if (vNodeKeys.empty()) continue;
        cv::KeyPoint* pKP = &vNodeKeys[0];
        float maxResponse = pKP->response;
        for (size_t k = 1; k < vNodeKeys.size(); ++k) {
            if (vNodeKeys[k].response > maxResponse) {
                pKP = &vNodeKeys[k];
                maxResponse = vNodeKeys[k].response;
            }
        }
        vResultKeys.push_back(*pKP);
    }
    return vResultKeys;
}

void SuperPointExtractor::ComputeKeyPointsSPStyle(
    std::vector<std::vector<cv::KeyPoint>>& allKeypoints,
    cv::Mat& outDesc)
{
    allKeypoints.clear();
    allKeypoints.resize(nlevels);
    std::vector<cv::Mat> vDesc; vDesc.reserve(nlevels);

    SPDetector detector(mModel, mUseCUDA);
    const float W = 30.f;

    torch::NoGradGuard _no_grad;
    for (int level = 0; level < nlevels; ++level) {
        const cv::Mat& imL = mvImagePyramid[level];
        detector.detect(const_cast<cv::Mat&>(imL));

        // Valid area (coordinate system without borders)
        const int minBorderX = EDGE_THRESHOLD - 3;
        const int minBorderY = minBorderX;
        const int maxBorderX = imL.cols - EDGE_THRESHOLD + 3;
        const int maxBorderY = imL.rows - EDGE_THRESHOLD + 3;

        const float width  = (maxBorderX - minBorderX);
        const float height = (maxBorderY - minBorderY);

        const int nCols = std::max(1, (int)std::floor(width  / W));
        const int nRows = std::max(1, (int)std::floor(height / W));
        const int wCell = std::max(1, (int)std::ceil(width  / nCols));
        const int hCell = std::max(1, (int)std::ceil(height / nRows));

        std::vector<cv::KeyPoint> vToDistributeKeys;
        vToDistributeKeys.reserve(nfeatures * 10);

        for (int i = 0; i < nRows; ++i) {
            const float iniY = minBorderY + i * hCell;
            float maxY = iniY + hCell + 6;
            if (iniY >= maxBorderY - 3) continue;
            if (maxY > maxBorderY) maxY = maxBorderY;

            for (int j = 0; j < nCols; ++j) {
                const float iniX = minBorderX + j * wCell;
                float maxX = iniX + wCell + 6;
                if (iniX >= maxBorderX - 6) continue;
                if (maxX > maxBorderX) maxX = maxBorderX;

                std::vector<cv::KeyPoint> vCell;
                detector.getKeyPoints(mIniThFAST, iniX, maxX, iniY, maxY, vCell, mUseNMS);
                if (vCell.empty())
                    detector.getKeyPoints(mMinThFAST, iniX, maxX, iniY, maxY, vCell, mUseNMS);

                for (auto& kp : vCell) {
                    kp.pt.x += j * wCell;
                    kp.pt.y += i * hCell;
                    vToDistributeKeys.emplace_back(std::move(kp));
                }
            }
        }

        // Octree homogenization + limit number
        auto& keypointsL = allKeypoints[level];
        keypointsL.reserve(mnFeaturesPerLevel[level]);
        keypointsL = DistributeOctTree(vToDistributeKeys,
                                       minBorderX, maxBorderX,
                                       minBorderY, maxBorderY,
                                       mnFeaturesPerLevel[level], level);

        const int scaledPatch = PATCH_SIZE * mvScaleFactor[level];
        for (auto& kp : keypointsL) {
            kp.pt.x += minBorderX;
            kp.pt.y += minBorderY;
            kp.octave = level;
            kp.size   = (float)scaledPatch;
            kp.angle  = 0.f;
        }

        cv::Mat descL;
        detector.computeDescriptors(keypointsL, descL);
        vDesc.emplace_back(std::move(descL));
    }

    if (!vDesc.empty()) cv::vconcat(vDesc, outDesc);
    else outDesc.release();
}

void SuperPointExtractor::operator()(cv::InputArray image,
                                     cv::InputArray mask,
                                     std::vector<cv::KeyPoint>& keypoints,
                                     cv::OutputArray descriptors)
{
    keypoints.clear();
    descriptors.release();
    if (image.empty()) return;

    cv::Mat im = image.getMat();
    cv::Mat gray;
    if (im.channels() > 1) cv::cvtColor(im, gray, cv::COLOR_BGR2GRAY);
    else gray = im;
    // Base pyramid (consistent EDGE_THRESHOLD/PATCH_SIZE with ORB-SLAM2)
    FeatureExtractor::ComputePyramid(gray);

    std::vector<std::vector<cv::KeyPoint>> allKeypoints;
    cv::Mat descAll;
    ComputeKeyPointsSPStyle(allKeypoints, descAll);

    int total = 0;
    for (int l = 0; l < nlevels; ++l) total += (int)allKeypoints[l].size();
    if (total == 0) { descriptors.release(); keypoints.clear(); return; }

    // copy descriptors
    descriptors.create(total, descAll.cols, CV_32F);
    descAll.copyTo(descriptors.getMat());

    // aggregate keypoints (rescale to original image)
    keypoints.reserve(total);
    for (int level = 0; level < nlevels; ++level) {
        auto& vK = allKeypoints[level];
        if (vK.empty()) continue;
        if (level != 0) {
            const float s = mvScaleFactor[level];
            for (auto& kp : vK) kp.pt *= s;
        }
        keypoints.insert(keypoints.end(), vK.begin(), vK.end());
    }
}

void SuperPointExtractor::ForceLinking() {}

} // namespace ORB_SLAM2

// ---------- Factory registrar ----------
namespace {
struct SuperPointRegister {
    SuperPointRegister() {
        std::cout << "Registering SuperPointExtractor..." << std::endl;
        ORB_SLAM2::FeatureExtractorFactory::Instance().Register("SuperPoint",
            [](const cv::FileNode& cfg, const bool init){
                return new ORB_SLAM2::SuperPointExtractor(cfg, init);
            });
    }
};
static SuperPointRegister g_registrar;
}