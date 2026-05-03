#' Customer timeline processor
#'
#' A lightweight S7 class that stores the column mapping and timeline options
#' used by `calculate_customer_timeline()`. Use `calculate_timeline()` to apply
#' the configured processor to a data.frame or data.table.
#'
#' @param id_column Character string. Name of the customer ID column.
#' @param from_column Character string. Name of the start date column.
#' @param to_column Character string. Name of the end date column.
#' @param characteristic_beg_columns Character vector. Column names that should
#'   preserve beginning values.
#' @param characteristic_end_columns Character vector. Column names that should
#'   take ending values.
#' @param gap_threshold Numeric or difftime. Maximum gap between periods to merge.
#' @param gap_units Character string. Units for numeric gap thresholds.
#' @param time_class Character string. One of `"auto"`, `"date"`, or
#'   `"datetime"`.
#' @param keep_all_periods Logical. If TRUE, keep internal period diagnostics.
#' @param verbose Logical. If TRUE, print processing time and result summary.
#' @param output_columns Character vector or NULL. Columns to include in output.
#' @param include_gap_column Logical. If TRUE and `keep_all_periods` is TRUE,
#'   include the gap diagnostic column.
#' @param copy_data Logical. If TRUE, work on a copy of the input data.
#'
#' @return A `CustomerTimeline` S7 object.
#'
#' @examples
#' \dontrun{
#' processor <- CustomerTimeline(
#'   id_column = "CustomerID",
#'   from_column = "StartDate",
#'   to_column = "EndDate",
#'   characteristic_beg_columns = "StatusBeg",
#'   characteristic_end_columns = "StatusEnd",
#'   verbose = FALSE
#' )
#'
#' calculate_timeline(processor, customer_data)
#' }
#'
#' @export
CustomerTimeline <- S7::new_class(
  "CustomerTimeline",
  package = "customerRelationship",
  properties = list(
    id_column = S7::new_property(S7::class_character, default = "ID"),
    from_column = S7::new_property(S7::class_character, default = "From"),
    to_column = S7::new_property(S7::class_character, default = "To"),
    characteristic_beg_columns = S7::new_property(
      S7::class_character,
      default = "CharacteristicBeg"
    ),
    characteristic_end_columns = S7::new_property(
      S7::class_character,
      default = c("CharacteristicEnd1", "CharacteristicEnd2")
    ),
    gap_threshold = S7::new_property(S7::class_any, default = 1),
    gap_units = S7::new_property(S7::class_character, default = "auto"),
    time_class = S7::new_property(S7::class_character, default = "auto"),
    keep_all_periods = S7::new_property(S7::class_logical, default = FALSE),
    verbose = S7::new_property(S7::class_logical, default = TRUE),
    output_columns = S7::new_property(S7::class_any, default = NULL),
    include_gap_column = S7::new_property(S7::class_logical, default = TRUE),
    copy_data = S7::new_property(S7::class_logical, default = TRUE)
  ),
  validator = function(self) {
    validate_customer_timeline_config(
      id_column = self@id_column,
      from_column = self@from_column,
      to_column = self@to_column,
      characteristic_beg_columns = self@characteristic_beg_columns,
      characteristic_end_columns = self@characteristic_end_columns,
      gap_threshold = self@gap_threshold,
      gap_units = self@gap_units,
      time_class = self@time_class,
      keep_all_periods = self@keep_all_periods,
      verbose = self@verbose,
      output_columns = self@output_columns,
      include_gap_column = self@include_gap_column,
      copy_data = self@copy_data
    )
  }
)

#' Calculate a timeline with a configured processor
#'
#' @param processor A `CustomerTimeline` object.
#' @param data_frame A data.frame or data.table containing relationship data.
#' @param ... Reserved for future extensions.
#'
#' @return A data.table with merged periods.
#'
#' @export
calculate_timeline <- S7::new_generic(
  "calculate_timeline",
  "processor",
  function(processor, data_frame, ...) {
    S7::S7_dispatch()
  }
)

S7::method(calculate_timeline, CustomerTimeline) <- function(processor,
                                                            data_frame,
                                                            ...) {
  dots <- list(...)
  if (length(dots) > 0L) {
    stop("Unused arguments: ", paste(names(dots), collapse = ", "), call. = FALSE)
  }

  calculate_customer_timeline(
    data_frame = data_frame,
    gap_threshold = processor@gap_threshold,
    gap_units = processor@gap_units,
    id_column = processor@id_column,
    from_column = processor@from_column,
    to_column = processor@to_column,
    time_class = processor@time_class,
    characteristic_beg_columns = processor@characteristic_beg_columns,
    characteristic_end_columns = processor@characteristic_end_columns,
    keep_all_periods = processor@keep_all_periods,
    verbose = processor@verbose,
    output_columns = processor@output_columns,
    include_gap_column = processor@include_gap_column,
    copy_data = processor@copy_data
  )
}

#' Validate CustomerTimeline configuration
#' @noRd
validate_customer_timeline_config <- function(id_column,
                                              from_column,
                                              to_column,
                                              characteristic_beg_columns,
                                              characteristic_end_columns,
                                              gap_threshold,
                                              gap_units,
                                              time_class,
                                              keep_all_periods,
                                              verbose,
                                              output_columns,
                                              include_gap_column,
                                              copy_data) {
  problems <- character()

  problems <- c(
    problems,
    validate_scalar_character(id_column, "@id_column"),
    validate_scalar_character(from_column, "@from_column"),
    validate_scalar_character(to_column, "@to_column"),
    validate_non_empty_character(characteristic_beg_columns, "@characteristic_beg_columns"),
    validate_non_empty_character(characteristic_end_columns, "@characteristic_end_columns"),
    validate_scalar_logical(keep_all_periods, "@keep_all_periods"),
    validate_scalar_logical(verbose, "@verbose"),
    validate_scalar_logical(include_gap_column, "@include_gap_column"),
    validate_scalar_logical(copy_data, "@copy_data")
  )

  valid_gap_units <- c("auto", "days", "hours", "mins", "secs")
  if (length(gap_units) != 1L || is.na(gap_units) || !gap_units %in% valid_gap_units) {
    problems <- c(
      problems,
      "@gap_units must be one of 'auto', 'days', 'hours', 'mins', or 'secs'"
    )
  }

  valid_time_classes <- c("auto", "date", "datetime")
  if (length(time_class) != 1L || is.na(time_class) || !time_class %in% valid_time_classes) {
    problems <- c(
      problems,
      "@time_class must be one of 'auto', 'date', or 'datetime'"
    )
  }

  if (length(gap_units) == 1L && !is.na(gap_units) && gap_units %in% valid_gap_units) {
    gap_problem <- tryCatch(
      {
        normalize_gap_threshold(gap_threshold, "date", gap_units)
        NULL
      },
      error = function(e) paste0("@gap_threshold ", conditionMessage(e))
    )
    problems <- c(problems, gap_problem)
  }

  if (!is.null(output_columns)) {
    problems <- c(
      problems,
      validate_non_empty_character(output_columns, "@output_columns")
    )
  }

  if (length(problems) == 0L) {
    return(NULL)
  }

  problems
}

#' Validate a non-empty scalar character value
#' @noRd
validate_scalar_character <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    return(paste0(name, " must be a non-empty character string"))
  }

  NULL
}

#' Validate a non-empty character vector
#' @noRd
validate_non_empty_character <- function(x, name) {
  if (!is.character(x) || length(x) == 0L || anyNA(x) || any(!nzchar(x))) {
    return(paste0(name, " must be a non-empty character vector"))
  }

  NULL
}

#' Validate a scalar logical value
#' @noRd
validate_scalar_logical <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    return(paste0(name, " must be TRUE or FALSE"))
  }

  NULL
}
