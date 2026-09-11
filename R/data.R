#' Path to the bundled example hazard-ratio meta-analysis dataset
#'
#' Returns the file path to a small example dataset (10 studies) bundled
#' with the package, suitable for trying out \code{\link{tsa_hr}}.
#'
#' @return A character string giving the path to the example .xlsx file.
#' @examples
#' path <- tsahr_example_data()
#' d <- readxl::read_excel(path)
#' head(d)
#' @export
tsahr_example_data <- function() {
  system.file("extdata", "HR_meta_example.xlsx", package = "tsahr")
}
