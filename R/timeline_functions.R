#' Internal validator for customer relationship data
#'
#' Checks that input data has the required columns before timeline processing.
#'
#' @noRd
validate_customer_data <- function(data_frame,
                                 id_column = "ID",
                                 from_column = "From",
                                 to_column = "To",
                                 characteristic_beg_columns = "CharacteristicBeg",
                                 characteristic_end_columns = c("CharacteristicEnd1", "CharacteristicEnd2")) {

  required_cols <- c(id_column, from_column, to_column,
                    characteristic_beg_columns, characteristic_end_columns)

  if (!is.data.frame(data_frame)) {
    stop("Input must be a data.frame or data.table", call. = FALSE)
  }

  missing_cols <- setdiff(required_cols, names(data_frame))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  if (nrow(data_frame) == 0) {
    stop("Input data is empty", call. = FALSE)
  }

  invisible(TRUE)
}


#' Calculate Customer Relationship Timeline
#'
#' Process customer relationship data to identify and merge consecutive periods
#' with gaps up to a configurable threshold. Uses Rcpp for efficient C++ processing and
#' data.table for scalability.
#'
#' @param data_frame A data.frame or data.table containing customer relationship data
#' @param gap_threshold Numeric or difftime. Maximum gap between periods to merge
#'   (default: 1 day)
#' @param gap_units Character string. Units for numeric gap_threshold values. One of
#'   "auto", "days", "hours", "mins", or "secs". "auto" preserves the legacy
#'   day-based interpretation (default: "auto")
#' @param id_column Character string. Name of the customer ID column
#' @param from_column Character string. Name of the start date column
#' @param to_column Character string. Name of the end date column
#' @param time_class Character string. One of "auto", "date", or "datetime".
#'   Use "datetime" to preserve intra-day resolution for POSIXct-style inputs
#'   (default: "auto")
#' @param characteristic_beg_columns Character vector. Column names that should preserve beginning values
#' @param characteristic_end_columns Character vector. Column names that should take ending values
#' @param keep_all_periods Logical. If TRUE, keep the raw internal rows with
#'   gap diagnostics for debugging, including a period_start column that marks
#'   rows included in the normal merged-period output (default: FALSE)
#' @param verbose Logical. If TRUE, print processing time and result summary (default: TRUE)
#' @param output_columns Character vector. Columns to include in output. If NULL, includes all relevant columns (default: NULL)
#' @param include_gap_column Logical. If TRUE and keep_all_periods is TRUE, include the Difference column showing gaps (default: TRUE)
#' @param copy_data Logical. If TRUE, work on a copy of the input data. If FALSE, modify input data in place (default: TRUE)
#'
#' @return A data.table with merged periods, including:
#'   - ID column (name specified by id_column)
#'   - From column (name specified by from_column)
#'   - To column (name specified by to_column)
#'   - Beginning characteristic columns (preserve first period values)
#'   - Ending characteristic columns (take last period values)
#'   - Difference: Gap to the active merge period, returned in days for Date timelines
#'     and as difftime seconds for datetime timelines (only when keep_all_periods = TRUE
#'     and include_gap_column = TRUE)
#'   - period_start: Logical flag returned when keep_all_periods = TRUE. TRUE
#'     marks rows included in the normal merged-period output.
#'
#' @details
#' The function performs the following operations:
#' 1. Validates input data structure
#' 2. Converts to data.table if necessary
#' 3. Detects whether the timeline should be handled as Date or datetime data
#' 4. Coerces the temporal columns while preserving the requested granularity
#' 5. Sorts by ID and From date
#' 6. Calls the C++ merge function to identify and merge continuous periods
#' 7. Returns one row per merged period, matching the legacy endvers.R output
#' 8. Selects output columns based on output_columns parameter
#'
#' Processing time is printed to console upon completion when verbose = TRUE.
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' data <- data.table::data.table(
#'   ID = c("CUS001", "CUS001", "CUS001", "CUS002"),
#'   From = as.Date(c("2020-01-01", "2020-01-02", "2020-02-01", "2020-01-15")),
#'   To = as.Date(c("2020-01-01", "2020-01-03", "2020-02-05", "2020-01-20")),
#'   CharacteristicBeg = c("Active", "Active", "Active", "Active"),
#'   CharacteristicEnd1 = c("Type1", "Type1", "Type1", "Type1"),
#'   CharacteristicEnd2 = c("Cat_A", "Cat_B", "Cat_B", "Cat_C")
#' )
#'
#' timeline <- calculate_customer_timeline(
#'   data,
#'   id_column = "ID",
#'   from_column = "From",
#'   to_column = "To",
#'   characteristic_beg_columns = "CharacteristicBeg",
#'   characteristic_end_columns = c("CharacteristicEnd1", "CharacteristicEnd2")
#' )
#' print(timeline)
#'
#' # Custom column names with multiple characteristics
#' data2 <- data.table::data.table(
#'   CustomerID = c("A", "A", "B"),
#'   StartDate = c("2020-01-01", "2020-01-02", "2020-02-01"),
#'   EndDate = c("2020-01-01", "2020-01-03", "2020-02-05"),
#'   StatusBeg = c("New", "New", "Returning"),
#'   StatusEnd = c("Active", "Active", "Active"),
#'   TypeBeg = c("Premium", "Premium", "Basic"),
#'   TypeEnd = c("Premium", "Gold", "Gold")
#' )
#'
#' timeline2 <- calculate_customer_timeline(data2,
#'                                         id_column = "CustomerID",
#'                                         from_column = "StartDate",
#'                                         to_column = "EndDate",
#'                                         characteristic_beg_columns = c("StatusBeg", "TypeBeg"),
#'                                         characteristic_end_columns = c("StatusEnd", "TypeEnd"))
#' print(timeline2)
#'
#' # Datetime workflow with a 30-minute continuity window
#' events <- data.table::data.table(
#'   ID = c("CUS001", "CUS001", "CUS001"),
#'   From = as.POSIXct(
#'     c("2020-01-01 10:00:00", "2020-01-01 10:45:00", "2020-01-01 12:00:00"),
#'     tz = "UTC"
#'   ),
#'   To = as.POSIXct(
#'     c("2020-01-01 10:30:00", "2020-01-01 11:00:00", "2020-01-01 12:30:00"),
#'     tz = "UTC"
#'   ),
#'   CharacteristicBeg = c("Active", "Active", "Active"),
#'   CharacteristicEnd1 = c("Checkout", "Checkout", "Support"),
#'   CharacteristicEnd2 = c("Web", "Web", "Phone")
#' )
#'
#' session_timeline <- calculate_customer_timeline(
#'   events,
#'   id_column = "ID",
#'   from_column = "From",
#'   to_column = "To",
#'   characteristic_beg_columns = "CharacteristicBeg",
#'   characteristic_end_columns = c("CharacteristicEnd1", "CharacteristicEnd2"),
#'   gap_threshold = 30,
#'   gap_units = "mins"
#' )
#' print(session_timeline)
#'
#' # Select specific output columns
#' timeline3 <- calculate_customer_timeline(data2,
#'                                         id_column = "CustomerID",
#'                                         from_column = "StartDate",
#'                                         to_column = "EndDate",
#'                                         characteristic_beg_columns = c("StatusBeg", "TypeBeg"),
#'                                         characteristic_end_columns = c("StatusEnd", "TypeEnd"),
#'                                         output_columns = c("CustomerID", "StartDate",
#'                                                            "EndDate", "StatusBeg",
#'                                                            "TypeEnd"))
#' print(timeline3)
#' }
#'
#' @export
calculate_customer_timeline <- function(data_frame,
                                      gap_threshold = 1,
                                      gap_units = "auto",
                                      id_column,
                                      from_column,
                                      to_column,
                                      time_class = c("auto", "date", "datetime"),
                                      characteristic_beg_columns,
                                      characteristic_end_columns,
                                      keep_all_periods = FALSE,
                                      verbose = TRUE,
                                      output_columns = NULL,
                                      include_gap_column = TRUE,
                                      copy_data = TRUE) {

  # Validate input
  validate_customer_data(data_frame, id_column, from_column, to_column,
                        characteristic_beg_columns, characteristic_end_columns)

  time_class <- detect_time_class(
    data_frame[[from_column]],
    data_frame[[to_column]],
    time_class
  )
  gap_threshold_value <- normalize_gap_threshold(gap_threshold, time_class, gap_units)

  if (verbose) {
    # Start timing
    start_time <- Sys.time()
    timeline_completed <- FALSE

    on.exit({
      if (timeline_completed) {
        # End timing and report
        end_time <- Sys.time()
        elapsed <- round(difftime(end_time, start_time, units = "secs"), 1)

        message("Customer relationship timeline calculated in ", elapsed,
                " secs. Returned ", nrow(result), " periods.")
      }
    }, add = TRUE)
  }

  # Convert to data.table if needed and handle copying
  dtable <- data_frame
  if (data.table::is.data.table(dtable)) {
    if (copy_data) {
      dtable <- data.table::copy(dtable)
    }
  } else if (copy_data) {
    dtable <- data.table::as.data.table(dtable)
  } else {
    data.table::setDT(dtable)
  }

  if (!data.table::is.data.table(dtable)) {
    dtable <- data.table::copy(dtable)
  }

  # Coerce temporal columns while preserving date vs datetime behavior
  for (col in c(from_column, to_column)) {
    data.table::set(
      dtable,
      j = col,
      value = coerce_temporal_column(dtable[[col]], time_class)
    )
  }

  # Sort by ID and From date
  data.table::setorderv(dtable, c(id_column, from_column))

  # Apply Rcpp merge function
  merged_dt <- data.table::as.data.table(
    merge_relationship_periods(dtable, id_column, from_column, to_column,
                              characteristic_beg_columns, characteristic_end_columns,
                              gap_threshold_value, keep_all_periods)
  )

  period_start <- is.na(merged_dt$Difference) | merged_dt$Difference > gap_threshold_value

  # Keep raw internal rows for debugging, or one row per merged period for normal output.
  result <- if (keep_all_periods) merged_dt else merged_dt[period_start]
  if (keep_all_periods) {
    result[, period_start := period_start]
  }

  # Keep gap diagnostics only when requested.
  if (!keep_all_periods || !include_gap_column) {
    result[, Difference := NULL]
  } else {
    result[, Difference := restore_gap_difference(Difference, time_class)]
  }

  # Select output columns if specified
  if (!is.null(output_columns)) {
    # Ensure all requested columns exist in the result
    available_cols <- names(result)
    missing_cols <- setdiff(output_columns, available_cols)
    if (length(missing_cols) > 0) {
      stop("Requested output columns not found in result: ",
           paste(missing_cols, collapse = ", "), call. = FALSE)
    }
    result <- result[, .SD, .SDcols = output_columns]
  }

  if (verbose) {
    timeline_completed <- TRUE
  }

  return(result)
}
