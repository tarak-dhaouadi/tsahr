## Frozen copy of the 10-study example dataset that shipped as
## inst/extdata/HR_meta_example.xlsx up to 0.2.7.22. From 0.2.8 the package
## bundles two different example datasets (see ?tsahr_example_data), but many
## tests pin numbers computed on THIS dataset (boundaries, DARIS, D2, the
## RTSA parity checks, ...), so they keep reading the frozen copy from
## tests/testthat/testdata/ instead of the bundled example.
##
## Note that this file stores several headers with spaces ("Events
## Treatment"), which tsa_hr() normalises to underscores on load; the bundled
## 0.2.8 examples already use underscores.
legacy_example_data <- function() {
  testthat::test_path("testdata", "HR_meta_legacy_10studies.xlsx")
}
