#ifndef PERF_H
#define PERF_H

#pragma once
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace ORB_SLAM2 { namespace Perf {

    struct Stats {
        uint64_t n = 0;
        double   sum = 0.0;
		double   sumsq = 0.0;
        double   minv = std::numeric_limits<double>::infinity();
        double   maxv = 0.0;
		std::vector<double> samples;

        void add(double ms) {
            ++n; sum += ms; sumsq += ms * ms;
    		if (ms < minv) minv = ms;
    		if (ms > maxv) maxv = ms;
    		samples.push_back(ms);
        }
    };

    void init(int Ntype = 0);
    void record(const std::string& name, double ms);
    void dump();

    struct Scoped {
        std::string name;
        std::chrono::steady_clock::time_point t0;
        explicit Scoped(std::string n)
          : name(std::move(n)), t0(std::chrono::steady_clock::now()) {}
        ~Scoped() {
            auto t1 = std::chrono::steady_clock::now();
            double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
            record(name, ms);
        }
    };

}} // namespace ORB_SLAM2


#endif //PERF_H
