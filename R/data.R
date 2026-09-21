#' Path to a bundled example hazard-ratio meta-analysis dataset
#'
#' Returns the file path to one of the two example datasets bundled with the
#' package, suitable for trying out \code{\link{tsa_hr}}. Both are
#' \code{.xlsx} sheets with one row per study and the columns
#' \code{Study}, \code{Ethnicity}, \code{Age}, \code{HR}, \code{lower},
#' \code{upper}, \code{log_HR}, \code{Std_Error}, \code{Events_Treatment},
#' \code{N_treatment}, \code{Events_controls} and \code{N_controls}
#' (the last seven are the ones \code{tsa_hr()} uses).
#'
#' @param dataset Which example to return: \code{"HR_meta"} (default; 20
#'   studies) or \code{"HR_meta_2"} (40 studies).
#'
#' @details
#' Before 0.2.8 the package bundled a single 10-study example
#' (\code{HR_meta_example.xlsx}); it was replaced by the two datasets above.
#' The package's own test suite keeps a frozen copy of the old dataset (its
#' numerical results are pinned by tests), so this change affects only what
#' \code{tsahr_example_data()} returns.
#'
#' @return A character string giving the path to the example .xlsx file.
#' @examples
#' path <- tsahr_example_data()          # 20 studies
#' d <- readxl::read_excel(path)
#' head(d)
#'
#' path2 <- tsahr_example_data("HR_meta_2")  # 40 studies
#' nrow(readxl::read_excel(path2))
#' @export
tsahr_example_data <- function(dataset = c("HR_meta", "HR_meta_2")) {
  dataset <- match.arg(dataset)
  system.file("extdata", paste0(dataset, ".xlsx"), package = "tsahr")
}
