// Standalone (no R) build of rtsa_core.h for regression tests:
//   g++ -O2 -shared -fPIC -DRTSA_STANDALONE -I../src rtsa_standalone.cpp -o librtsa_standalone.so
#include "rtsa_core.h"
#include <cstring>
#include <string>
static std::string g_last_error;
extern "C" {
// 0.2.7.14: classify the interval handling of z_n_w() for a single look.
// Returns the number of Simpson nodes; counters via out-pointers.
int sa_znw_diag(double za_i, double zb_i, double delta, int* collapses,
                int* reversed) {
  rtsa::vec sd(1, 1.0), za(1, za_i), zb(1, zb_i);
  rtsa::Diagnostics d;
  rtsa::Grid g = rtsa::z_n_w(18, sd, za, zb, 1, delta, &d);
  *collapses = d.grid_collapses;
  *reversed  = d.grid_reversed;
  return (int)g.zj.size();
}
int sa_alpha(const double* t, int n, int side, double alpha, double design_R,
             double* zb_out) {
  try {
    rtsa::AlphaOut a = rtsa::alpha_boundary(rtsa::vec(t, t + n), side, alpha, design_R);
    for (int i = 0; i < n; ++i) zb_out[i] = a.zb[i];
    return 0;
  } catch (std::exception& e) { g_last_error = e.what(); return 1; }
  catch (...) { return 1; }
}
// returns number of looks used (nn) or -1 on error
// 0.2.7.15: `unreachable_look` receives BetaOut::unreachable_look (0 = none).
int sa_beta(const double* t, int n, const double* ub, int n_ub, double beta,
            int side, double delta, int rm_bs, double design_R, double warp_root,
            double* za_out, double* incr_out, int* unreachable_look) {
  try {
    rtsa::BetaOut b = rtsa::beta_boundary(rtsa::vec(t, t + n), rtsa::vec(ub, ub + n_ub),
                                          beta, side, delta, rm_bs, design_R, warp_root);
    for (size_t i = 0; i < b.za.size(); ++i) { za_out[i] = b.za[i]; incr_out[i] = b.as_incr[i]; }
    *unreachable_look = b.unreachable_look;
    return (int)b.za.size();
  } catch (std::exception& e) { g_last_error = e.what(); return -1; }
  catch (...) { return -1; }
}
// 0.2.7.16: classify a single beta searchfunc() call on a synthetic look:
//   0 = converged, 1 = SearchUnreachable (target > qmax), 2 = hard error
//   (reachable target, search failed within max_outer rounds).
// The synthetic `last` is the density of a first look on a +-4 grid, so
// qmax = sum(last) ~= 1.
int sa_search_classify(double as_target, int max_outer, double* qmax_out) {
  rtsa::vec zj, wj, sd_incr(2, 1.0), sd_proc(2, 1.0), za(2, -5.0), zb(2, 5.0);
  sd_proc[1] = std::sqrt(2.0);
  for (int k = 0; k <= 80; ++k) { zj.push_back(-4.0 + 0.1 * k); wj.push_back(0.1); }
  rtsa::vec last = rtsa::init_int(wj, zj, 0.0, 1.0);
  double qmax = 0.0; for (size_t q = 0; q < last.size(); ++q) qmax += last[q];
  *qmax_out = qmax;
  try {
    rtsa::searchfunc(last, zj, 2, as_target, sd_incr, sd_proc, za, zb, 1e-15,
                     true, 2.8, nullptr, max_outer);
    return 0;
  } catch (const rtsa::SearchUnreachable&) { return 1; }
  catch (std::exception& e) { g_last_error = e.what(); return 2; }
}
int sa_last_error(char* buf, int n) {
  std::strncpy(buf, g_last_error.c_str(), n - 1); buf[n - 1] = 0;
  return (int)g_last_error.size();
}
}
