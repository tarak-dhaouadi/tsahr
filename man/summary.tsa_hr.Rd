\name{summary.tsa_hr}
\alias{summary.tsa_hr}
\title{Summarise a tsa_hr object}
\usage{
\method{summary}{tsa_hr}(object, ...)
}
\arguments{
\item{object}{An object of class \code{"tsa_hr"}.}

\item{...}{Currently unused.}
}
\value{
The underlying summary data.frame (invisibly printed).
}
\description{
Prints \code{object$summary_table} (\code{Parameter}/\code{Value}); since
0.2.8.12 \code{Parameter} uses short abbreviations (e.g. \code{"DARIS"},
\code{"AR endpoint"}, \code{"RE"}) to keep the table readable, and an
\dQuote{Abbreviations:} line spelling them out is printed directly below
the table (from \code{attr(object$summary_table, "abbreviations")}).
}
