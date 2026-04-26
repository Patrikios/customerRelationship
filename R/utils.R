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
  if (is_date_column(x)) {
    return(x)
  }

  parse_date_values(x)
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

#' Detect whether character-like input contains time information
#' @noRd
looks_like_datetime <- function(x) {
  if (inherits(x, c("Date", "POSIXt"))) {
    return(inherits(x, "POSIXt"))
  }

  if (is.factor(x)) {
    x <- as.character(x)
  }

  if (!is.character(x)) {
    return(FALSE)
  }

  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) {
    return(FALSE)
  }

  probe <- utils::head(x, 100L)
  any(grepl("[T ]\\d{1,2}:\\d{2}", probe) |
        grepl("Z$", probe) |
        grepl("[+-]\\d{2}:?\\d{2}$", probe))
}

#' Decide whether timelines should be processed as dates or datetimes
#' @noRd
detect_time_class <- function(from_value, to_value, time_class = c("auto", "date", "datetime")) {
  time_class <- match.arg(time_class)

  if (time_class != "auto") {
    return(time_class)
  }

  if (inherits(from_value, "POSIXt") || inherits(to_value, "POSIXt")) {
    return("datetime")
  }

  if (inherits(from_value, "Date") && inherits(to_value, "Date")) {
    return("date")
  }

  if (looks_like_datetime(from_value) || looks_like_datetime(to_value)) {
    return("datetime")
  }

  "date"
}

#' Coerce temporal input while preserving the requested granularity
#' @noRd
coerce_temporal_column <- function(x, time_class = c("date", "datetime")) {
  time_class <- match.arg(time_class)

  if (time_class == "datetime") {
    if (inherits(x, "POSIXct")) {
      return(x)
    }
    if (inherits(x, "POSIXlt")) {
      return(as.POSIXct(x))
    }
    if (inherits(x, "Date")) {
      return(as.POSIXct(x))
    }
    return(parse_datetime_values(x))
  }

  if (inherits(x, "Date")) {
    return(x)
  }
  if (inherits(x, "POSIXt")) {
    return(as.Date(x))
  }

  parse_date_values(x)
}

#' Parse date-like values using base R
#' @noRd
parse_date_values <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }

  parsed <- tryCatch(
    as.Date(
      x,
      tryFormats = c(
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%Y%m%d",
        "%d-%m-%Y",
        "%d/%m/%Y",
        "%m/%d/%Y"
      )
    ),
    error = function(e) rep(as.Date(NA), length(x))
  )

  if (any(is.na(parsed) & !is.na(x))) {
    stop("Unable to parse date values", call. = FALSE)
  }

  parsed
}

#' Parse datetime-like values using base R
#' @noRd
parse_datetime_values <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }

  if (is.character(x)) {
    x <- normalize_datetime_text(x)
  }

  parsed <- tryCatch(
    as.POSIXct(
      x,
      tz = "UTC",
      tryFormats = c(
        "%Y-%m-%d %H:%M:%OS%z",
        "%Y-%m-%dT%H:%M:%OS%z",
        "%Y/%m/%d %H:%M:%OS%z",
        "%Y/%m/%dT%H:%M:%OS%z",
        "%Y-%m-%d %H:%M:%OS",
        "%Y-%m-%dT%H:%M:%OS",
        "%Y/%m/%d %H:%M:%OS",
        "%Y/%m/%dT%H:%M:%OS",
        "%Y-%m-%d %H:%M%z",
        "%Y-%m-%dT%H:%M%z",
        "%Y/%m/%d %H:%M%z",
        "%Y/%m/%dT%H:%M%z",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%dT%H:%M",
        "%Y/%m/%d %H:%M",
        "%Y/%m/%dT%H:%M",
        "%Y-%m-%d",
        "%Y/%m/%d"
      )
    ),
    error = function(e) rep(as.POSIXct(NA, tz = "UTC"), length(x))
  )

  if (any(is.na(parsed) & !is.na(x))) {
    stop("Unable to parse datetime values", call. = FALSE)
  }

  parsed
}

#' Normalize ISO timezone spellings for base R parsing
#' @noRd
normalize_datetime_text <- function(x) {
  x <- sub("Z$", "+0000", x)
  sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", x)
}

#' Convert a user-facing gap threshold into the storage units used internally
#' @noRd
normalize_gap_threshold <- function(gap_threshold,
                                    time_class = c("date", "datetime"),
                                    gap_units = c("auto", "days", "hours", "mins", "secs")) {
  time_class <- match.arg(time_class)
  gap_units <- match.arg(gap_units)

  if (inherits(gap_threshold, "difftime")) {
    target_units <- if (time_class == "datetime") "secs" else "days"
    return(as.numeric(gap_threshold, units = target_units))
  }

  if (!is.numeric(gap_threshold) || length(gap_threshold) != 1L ||
      is.na(gap_threshold) || gap_threshold < 0) {
    stop(
      "gap_threshold must be a single non-negative number or difftime",
      call. = FALSE
    )
  }

  if (gap_units == "auto") {
    gap_units <- "days"
  }

  gap_value <- as.numeric(gap_threshold)
  seconds_value <- switch(
    gap_units,
    days = gap_value * 86400,
    hours = gap_value * 3600,
    mins = gap_value * 60,
    secs = gap_value
  )

  if (time_class == "datetime") {
    return(seconds_value)
  }

  seconds_value / 86400
}

#' Restore a user-friendly gap column after numeric processing
#' @noRd
restore_gap_difference <- function(x, time_class = c("date", "datetime")) {
  time_class <- match.arg(time_class)

  if (time_class == "datetime") {
    return(structure(as.numeric(x), class = "difftime", units = "secs"))
  }

  as.integer(x)
}
