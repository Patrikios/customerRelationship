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
#' @param gap_threshold Integer. Maximum gap (in days) between periods to merge (default: 1)
#' @param id_column Character string. Name of the customer ID column (default: "ID")
#' @param from_column Character string. Name of the start date column (default: "From")
#' @param to_column Character string. Name of the end date column (default: "To")
#' @param characteristic_beg_columns Character vector. Column names that should preserve beginning values (default: "CharacteristicBeg")
#' @param characteristic_end_columns Character vector. Column names that should take ending values (default: c("CharacteristicEnd1", "CharacteristicEnd2"))
#' @param keep_all_periods Logical. If TRUE, keep the internal gap diagnostics in the returned merged periods (default: FALSE)
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
#'   - Difference: Gap (in days) to previous period (only when keep_all_periods = TRUE and include_gap_column = TRUE)
#'
#' @details
#' The function performs the following operations:
#' 1. Validates input data structure
#' 2. Converts to data.table if necessary
#' 3. Coerces date columns to Date class
#' 4. Sorts by ID and From date
#' 5. Calls the C++ merge function to identify and merge continuous periods
#' 6. Returns one row per merged period, matching the legacy endvers.R output
#' 7. Selects output columns based on output_columns parameter
#'
#' Processing time is printed to console upon completion when verbose = TRUE.
#'
#' @examples
#' \dontrun{
#' # Basic usage with default column names
#' data <- data.table::data.table(
#'   ID = c("CUS001", "CUS001", "CUS001", "CUS002"),
#'   From = as.Date(c("2020-01-01", "2020-01-02", "2020-02-01", "2020-01-15")),
#'   To = as.Date(c("2020-01-01", "2020-01-03", "2020-02-05", "2020-01-20")),
#'   CharacteristicBeg = c("Active", "Active", "Active", "Active"),
#'   CharacteristicEnd1 = c("Type1", "Type1", "Type1", "Type1"),
#'   CharacteristicEnd2 = c("Cat_A", "Cat_B", "Cat_B", "Cat_C")
#' )
#'
#' timeline <- calculate_customer_timeline(data)
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
                                      id_column = "ID",
                                      from_column = "From",
                                      to_column = "To",
                                      characteristic_beg_columns = "CharacteristicBeg",
                                      characteristic_end_columns = c("CharacteristicEnd1", "CharacteristicEnd2"),
                                      keep_all_periods = FALSE,
                                      verbose = TRUE,
                                      output_columns = NULL,
                                      include_gap_column = TRUE,
                                      copy_data = TRUE) {

  # Validate input
  validate_customer_data(data_frame, id_column, from_column, to_column,
                        characteristic_beg_columns, characteristic_end_columns)

  if (!is.numeric(gap_threshold) || length(gap_threshold) != 1L ||
      is.na(gap_threshold) || gap_threshold < 0) {
    stop("gap_threshold must be a single non-negative number", call. = FALSE)
  }

  gap_threshold <- as.integer(gap_threshold)

  # Start timing
  start_time <- Sys.time()

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

  # Coerce date columns to Date class
  for (col in c(from_column, to_column)) {
    if (!inherits(dtable[[col]], "Date")) {
      data.table::set(dtable, j = col,
                      value = anytime::anydate(dtable[[col]]))
    }
  }

  # Sort by ID and From date
  data.table::setorderv(dtable, c(id_column, from_column))

  # Apply Rcpp merge function
  merged_dt <- data.table::as.data.table(
    merge_relationship_periods(dtable, id_column, from_column, to_column,
                              characteristic_beg_columns, characteristic_end_columns,
                              gap_threshold, keep_all_periods)
  )

  period_start <- is.na(merged_dt$Difference) | merged_dt$Difference > gap_threshold

  # Filter results based on keep_all_periods
  if (keep_all_periods) {
    result <- merged_dt[period_start]
  } else {
    result <- merged_dt[period_start]
  }

  # Handle gap column inclusion
  if (!keep_all_periods || !include_gap_column) {
    result[, Difference := NULL]
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

  # End timing and report
  end_time <- Sys.time()
  elapsed <- round(difftime(end_time, start_time, units = "secs"), 1)

  if (verbose) {
    message("Customer relationship timeline calculated in ", elapsed,
            " secs. Returned ", nrow(result), " periods.")
  }

  return(result)
}
