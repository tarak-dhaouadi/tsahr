## usethis namespace: start
#' @useDynLib tsahr, .registration = TRUE
#' @importFrom Rcpp sourceCpp
"_PACKAGE"
## usethis namespace: end
NULL

# log_HR and Std_Error are column names of the `data` argument, referenced
# via non-standard evaluation inside metafor::rma(yi = log_HR, sei = Std_Error,
# data = data, ...) -- exactly as in stats::lm() formulas. This declaration
# tells R CMD check these are not undefined global variables.
utils::globalVariables(c("log_HR", "Std_Error"))
