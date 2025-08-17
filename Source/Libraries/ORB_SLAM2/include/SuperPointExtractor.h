/**
 * >>> This is modified version of original SuperSLAM::SPextractor <<<
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

#ifndef SUPERPOINTEXTRACTOR_H
#define SUPERPOINTEXTRACTOR_H

#pragma once
#include "FeatureExtractor.h"
#include "SuperPoint.h"
#include "FeatureExtractorFactory.h"
#include <memory>
#include <string>
#include <list>

namespace ORB_SLAM2 {

    class SuperPointExtractor : public FeatureExtractor {
    public:
        SuperPointExtractor(const cv::FileNode& cfg, bool init);

        void InfoConfigs() override;

        void operator()(cv::InputArray image,
                        cv::InputArray mask,
                        std::vector<cv::KeyPoint>& keypoints,
                        cv::OutputArray descriptors) override;

        static void ForceLinking();

    private:
        struct ExtractorNode {
            std::vector<cv::KeyPoint> vKeys;
            cv::Point2i UL, UR, BL, BR;
            std::list<ExtractorNode>::iterator lit;
            bool bNoMore = false;

            void DivideNode(ExtractorNode& n1, ExtractorNode& n2,
                            ExtractorNode& n3, ExtractorNode& n4);
        };

        std::vector<cv::KeyPoint> DistributeOctTree(
            const std::vector<cv::KeyPoint>& vToDistributeKeys,
            const int& minX, const int& maxX, const int& minY, const int& maxY,
            const int& nFeatures, const int& level);

    private:
		std::unique_ptr<SuperSLAM::SPDetector> mDetector;
        std::shared_ptr<SuperSLAM::SuperPoint> mModel;
        float iniTh;
        float minTh;
        bool  mUseCUDA = false;
        bool  mUseNMS = true;
        std::string mWeightsPath;
    };

} // namespace ORB_SLAM2

#endif // SUPERPOINTEXTRACTOR_H
