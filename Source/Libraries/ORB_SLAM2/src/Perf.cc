#include "Perf.h"
#include <atomic>
#include <cstdlib>
#include <vector>

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
                  << std::right << std::setw(12) << "avg"
                  << std::setw(12) << "min"
                  << std::setw(12) << "max"
                  << std::setw(12) << "count" << "\n";
        for (auto& kv : g_tab) {
            const auto& s = kv.second;
            double avg = s.n ? (s.sum / s.n) : 0.0;
            double minv = (s.minv == std::numeric_limits<double>::infinity()) ? 0.0 : s.minv;
            std::cout << std::left  << std::setw(28) << kv.first
                      << std::right << std::setw(12) << std::fixed << std::setprecision(3) << avg
                      << std::setw(12) << minv
                      << std::setw(12) << s.maxv
                      << std::setw(12) << s.n
                      << "\n";
        }
    }

}} // namespace
