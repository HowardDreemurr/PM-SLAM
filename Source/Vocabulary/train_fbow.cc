// train_fbow.cpp
// .fbow dictionary for offline training ORB descriptors (depends on: fbow / ORB_SLAM2 / OpenCV)

#include <iostream>
#include <fstream>
#include <chrono>

#include <fbow.h>
#include <vocabulary_creator.h>

#include "ORBextractor.h"
using namespace ORB_SLAM2;


static std::vector<std::string> LoadImageList(const std::string &list)
{
    std::ifstream ifs(list);
    std::vector<std::string> v;
    for (std::string l; std::getline(ifs, l); )
        if (!l.empty()) v.push_back(l);
    return v;
}

int main(int argc, char **argv)
{
    if (argc < 5) {
        std::cerr << "Usage: " << argv[0]
                  << " <imagelist.txt> <out.fbow> <k> <L>\n";
        return 1;
    }

    std::string listFile = argv[1];
    std::string outFile  = argv[2];
    int k  = std::stoi(argv[3]);
    int L  = std::stoi(argv[4]);

    /* ---------- 1) Create Extractor ---------- */
    const int nFeatures   = 2000;
    const float scaleFactor = 1.2f;
    const int nLevels     = 8;
    const int iniThFAST   = 20;
    const int minThFAST   = 7;

    std::unique_ptr<ORBextractor> pExtractor = std::make_unique<ORBextractor>(
        nFeatures, scaleFactor, nLevels, iniThFAST, minThFAST);

    std::cout << "[FBoW Training] ORB extractor ready  ("
              << nFeatures << " features / img)\n";

    /* ---------- 2) Read Images & Extract Discriptors ---------- */
    auto vImg = LoadImageList(listFile);
    if (vImg.empty()) { std::cerr << "Empty imagelist\n"; return 2; }

    std::cout << "Total images: " << vImg.size() << "\n";

    std::vector<cv::Mat> all_desc;
    size_t total_feat = 0;
    auto t0 = std::chrono::steady_clock::now();

    size_t idx = 0;
    for (auto &path : vImg)
    {
        cv::Mat im = cv::imread(path, cv::IMREAD_GRAYSCALE);
        if (im.empty()) { std::cerr << "Skip " << path << "\n"; continue; }

        std::vector<cv::KeyPoint> kps;
        cv::Mat desc;
        (*pExtractor)(im, cv::Mat(), kps, desc);

        if (!desc.empty()) {
            total_feat += desc.rows;
            all_desc.push_back(desc);
        }

        if (++idx % 100 == 0)
        {
            double secs = std::chrono::duration<double>(
                              std::chrono::steady_clock::now() - t0).count();
            std::cout << "\r[" << idx << "/" << vImg.size()
                      << "] feats: " << total_feat
                      << "  (" << idx / secs << " img/s) " << std::flush;
        }
    }
    std::cout << "\nCollected descriptors: " << total_feat << "\n";
    if (all_desc.empty()) { std::cerr << "No descriptors!\n"; return 3; }

    /* ---------- 3) Train FBoW  ---------- */
    fbow::VocabularyCreator::Params param;
    param.k        = k;
    param.L        = L;
    param.nthreads = std::thread::hardware_concurrency();
    param.verbose  = true;

    fbow::Vocabulary voc;
    std::cout << "Training vocabulary (k=" << k << ", L=" << L << ") ...\n";
    fbow::VocabularyCreator().create(voc, all_desc, "ORB", param);

    /* ---------- 4) Save FBoW ---------- */
    voc.saveToFile(outFile);
    std::cout << "Saved vocabulary to: " << outFile << "\n";
    return 0;
}
