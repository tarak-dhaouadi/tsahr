# tools/ -- development-only, not part of the installed package

* `rtsa_port.py`  Python port of RTSA 0.2.2's boundary engine
  (alpha_boundary, beta_boundary, boundaries design/analysis). Reproduces RTSA's
  published futility-vignette output; used to pin the reference values in
  `tests/testthat/test-rtsa-engine-parity.R`.
* `rtsa_standalone.cpp` + `cpp_vs_py.py`  build `src/rtsa_core.h` without R
  (`g++ -O2 -shared -fPIC -DRTSA_STANDALONE -I../src rtsa_standalone.cpp
  -o librtsa_standalone.so`) and compare it with the Python port (~1e-14);
  since 0.2.7.14 it also checks the z_n_w() diagnostic classification
  (ordinary / degenerate / REVERSED interval); since 0.2.7.15 it runs the
  design-route calibration on the awkward schedules (section 7); since
  0.2.7.16 it checks the exact reachability classification of a beta search
  (section 8) and that 300 random 3-45-look schedules all calibrate (section 9);
  since 0.2.7.17 section 10 compares the core with numbers printed by the live
  RTSA 0.2.2 package (`inst/extdata/rtsa_0.2.2_reference.R`).
