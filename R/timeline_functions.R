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


#' Validate the configured gap threshold
#'
#' @noRd
validate_gap_threshold <- function(gap_threshold) {
  if (!is.numeric(gap_threshold) || length(gap_threshold) != 1L ||
      is.na(gap_threshold) || gap_threshold < 0) {
    stop("gap_threshold must be a single non-negative number", call. = FALSE)
  }

  as.integer(gap_threshold)
}


#' Prepare customer relationship data for timeline processing
#'
#' @noRd
prepare_customer_timeline_data <- function(data_frame,
                                         id_column,
                                         from_column,
                                         to_column,
                                         characteristic_beg_columns,
                                         characteristic_end_columns,
                                         copy_data) {
  validate_customer_data(data_frame, id_column, from_column, to_column,
                        characteristic_beg_columns, characteristic_end_columns)

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

  for (col in c(from_column, to_column)) {
    if (!inherits(dtable[[col]], "Date")) {
      data.table::set(dtable, j = col, value = anytime::anydate(dtable[[col]]))
    }
  }

  data.table::setorderv(dtable, c(id_column, from_column))
  dtable
}


#' Finalize timeline output
#'
#' @noRd
finalize_customer_timeline_result <- function(merged_dt,
                                            gap_threshold,
                                            keep_all_periods,
                                            output_columns,
                                            include_gap_column) {
  period_start <- is.na(merged_dt$Difference) | merged_dt$Difference > gap_threshold
  result <- merged_dt[period_start]

  if (!keep_all_periods || !include_gap_column) {
    result[, Difference := NULL]
  }

  if (!is.null(output_columns)) {
    missing_cols <- setdiff(output_columns, names(result))
    if (length(missing_cols) > 0) {
      stop("Requested output columns not found in result: ",
           paste(missing_cols, collapse = ", "), call. = FALSE)
    }
    result <- result[, .SD, .SDcols = output_columns]
  }

  result
}


#' Shared timeline runner
#'
#' @noRd
run_customer_timeline <- function(data_frame,
                                gap_threshold,
                                id_column,
                                from_column,
                                to_column,
                                characteristic_beg_columns,
                                characteristic_end_columns,
                                keep_all_periods,
                                verbose,
                                output_columns,
                                include_gap_column,
                                copy_data,
                                merge_fun) {
  gap_threshold <- validate_gap_threshold(gap_threshold)
  start_time <- Sys.time()

  dtable <- prepare_customer_timeline_data(
    data_frame = data_frame,
    id_column = id_column,
    from_column = from_column,
    to_column = to_column,
    characteristic_beg_columns = characteristic_beg_columns,
    characteristic_end_columns = characteristic_end_columns,
    copy_data = copy_data
  )

  merged_dt <- merge_fun(
    dtable = dtable,
    id_column = id_column,
    from_column = from_column,
    to_column = to_column,
    characteristic_beg_columns = characteristic_beg_columns,
    characteristic_end_columns = characteristic_end_columns,
    gap_threshold = gap_threshold,
    keep_all_periods = keep_all_periods
  )

  result <- finalize_customer_timeline_result(
    merged_dt = merged_dt,
    gap_threshold = gap_threshold,
    keep_all_periods = keep_all_periods,
    output_columns = output_columns,
    include_gap_column = include_gap_column
  )

  if (verbose) {
    elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 1)
    message("Customer relationship timeline calculated in ", elapsed,
            " secs. Returned ", nrow(result), " periods.")
  }

  result
}

