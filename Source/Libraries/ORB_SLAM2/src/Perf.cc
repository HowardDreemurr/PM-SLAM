#include "Perf.h"
#include <atomic>
#include <cstdlib>
#include <vector>
#include <algorithm>
#include <cmath>

namespace ORB_SLAM2 { namespace Perf {

    static std::mutex g_mtx;
    static std::unordered_map<std::string, Stats> g_tab;
    static std::atomic<bool> g_inited{false};

    static void at_exit_dump() { dump(); }

    void init(int) {
        bool expected = false;
        if (g_inited.compare_exchange_strong(expected, true)) {
            std::atexit(&at_exit_dump);
        }
    }

    void record(const std::string& name, double ms) {
        std::lock_guard<std::mutex> lk(g_mtx);
        g_tab[name].add(ms);
    }

    void dump() {
  		std::lock_guard<std::mutex> lk(g_mtx);
  		if (g_tab.empty()) return;

  		std::cout << "\n========== Performance Summary (ms) ==========\n";
  		std::cout << std::left << std::setw(28) << "name"
            << std::right << std::setw(12) << "mean"
            << std::setw(12) << "median"
            << std::setw(12) << "rmse"
            << std::setw(12) << "min"
            << std::setw(12) << "max"
            << std::setw(12) << "count" << "\n";

  		for (auto& kv : g_tab) {
    		const auto& s = kv.second;
   			 const double avg = s.n ? (s.sum / s.n) : 0.0;
   			 const double minv = (s.minv == std::numeric_limits<double>::infinity()) ? 0.0 : s.minv;

    // --- median ---
    double median = 0.0;
    if (!s.samples.empty()) {
      	std::vector<double> tmp = s.samples;
      	const size_t k = tmp.size() / 2;
      	std::nth_element(tmp.begin(), tmp.begin() + k, tmp.end());
      	median = tmp[k];
      	if (tmp.size() % 2 == 0) {
        	const auto max_lower = *std::max_element(tmp.begin(), tmp.begin() + k);
        	median = 0.5 * (median + max_lower);
      	}
    }

    // --- rmse ---
    double rmse = 0.0;
    if (s.n) {
      	double acc = 0.0;
      	for (double x : s.samples) {
        	const double d = x - avg;
        	acc += d * d;
      	}
      	rmse = std::sqrt(acc / static_cast<double>(s.n));
    }

    std::cout << std::left  << std::setw(28) << kv.first
              << std::right << std::setw(12) << std::fixed << std::setprecision(3) << avg
              << std::setw(12) << median
              << std::setw(12) << rmse
              << std::setw(12) << minv
              << std::setw(12) << s.maxv
              << std::setw(12) << s.n
              << "\n";
  }
}

}} // namespace
