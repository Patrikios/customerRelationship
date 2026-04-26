#' customerRelationship: Customer Relationship Timeline Processing
#'
#' Efficiently processes customer relationship data to identify and merge 
#' consecutive periods with minimal gaps using Rcpp for performance and 
#' data.table for scalability.
#'
#' @docType package
#' @name customerRelationship
#'
#' @importFrom Rcpp sourceCpp
#' @useDynLib customerRelationship, .registration = TRUE
#'
#' @import data.table
#'
#' @keywords internal
"_PACKAGE"

if (getRversion() >= "2.15.1") {
  utils::globalVariables("Difference")
}

## usethis namespace: start
## usethis namespace: end
NULL
