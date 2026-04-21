#' Utility Functions for Data Handling
#'
#' Internal utility functions for type conversion and data handling
#'
#' @keywords internal

#' Check if input is a data.table
#' @noRd
is_data_table <- function(x) {
  data.table::is.data.table(x)
}

#' Check if column contains Date class
#' @noRd
is_date_column <- function(x) {
  inherits(x, "Date")
}

#' Convert to proper date class
#' @noRd
coerce_to_date <- function(x) {
  if (!is_date_column(x)) {
    anytime::anydate(x)
  } else {
    x
  }
}

#' Create a copy of data without modifying original
#' @noRd
safe_copy <- function(dtable) {
  if (is_data_table(dtable)) {
    data.table::copy(dtable)
  } else {
    data.table::setDT(data.frame(dtable))
  }
}
