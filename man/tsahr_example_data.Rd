\name{tsahr_example_data}
\alias{tsahr_example_data}
\title{Path to the bundled example hazard-ratio meta-analysis dataset}
\usage{
tsahr_example_data()
}
\value{
A character string giving the path to the example .xlsx file.
}
\description{
Returns the file path to a small example dataset (10 studies) bundled
with the package, suitable for trying out \code{\link{tsa_hr}}.
}
\examples{
path <- tsahr_example_data()
d <- readxl::read_excel(path)
head(d)
}
