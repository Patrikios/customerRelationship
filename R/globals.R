#' Global variables for data.table non-standard evaluation
#'
#' These symbols are used in data.table expressions and are declared here to
#' satisfy static analysis checks from R CMD check and lintr.
#'
#' @noRd
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(".", ":=", ".SD", "Difference", "period_start"))
}
