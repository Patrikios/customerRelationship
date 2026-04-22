#' Build one merged period row from a grouped data.table slice
#'
#' @noRd
build_customer_timeline_period <- function(group_dt,
                                         from_column,
                                         to_column,
                                         characteristic_beg_columns,
                                         characteristic_end_columns,
                                         to_num_column) {
  max_idx <- which.max(group_dt[[to_num_column]])

  c(
    list(Difference = group_dt$Difference[1L]),
    setNames(list(group_dt[[from_column]][1L]), from_column),
    setNames(list(group_dt[[to_column]][max_idx]), to_column),
    setNames(
      lapply(characteristic_beg_columns, function(col) group_dt[[col]][1L]),
      characteristic_beg_columns
    ),
    setNames(
      lapply(characteristic_end_columns, function(col) group_dt[[col]][max_idx]),
      characteristic_end_columns
    )
  )
}


#' Pure data.table period merge implementation
#'
#' @noRd
merge_relationship_periods_data_table_impl <- function(dtable,
                                                     id_column,
                                                     from_column,
                                                     to_column,
                                                     characteristic_beg_columns,
                                                     characteristic_end_columns,
                                                     gap_threshold,
                                                     keep_all_periods) {
  dt <- data.table::copy(dtable)
  char_cols <- unique(c(id_column, characteristic_beg_columns, characteristic_end_columns))
  for (col in char_cols) {
    data.table::set(dt, j = col, value = as.character(dt[[col]]))
  }

  to_num_column <- ".timeline_to_num"
  running_to_column <- ".timeline_running_to"
  period_id_column <- ".timeline_period_id"

  dt[, (to_num_column) := as.integer(get(to_column))]
  dt[, (running_to_column) := cummax(get(to_num_column)), by = id_column]
  dt[, Difference := as.integer(get(from_column)) - data.table::shift(get(running_to_column)),
     by = id_column]
  dt[, (period_id_column) := cumsum(is.na(Difference) | Difference > gap_threshold),
     by = id_column]

  result <- dt[
    ,
    build_customer_timeline_period(
      group_dt = .SD,
      from_column = from_column,
      to_column = to_column,
      characteristic_beg_columns = characteristic_beg_columns,
      characteristic_end_columns = characteristic_end_columns,
      to_num_column = to_num_column
    ),
    by = c(id_column, period_id_column)
  ]

  result[, (period_id_column) := NULL]
  attributes(result[[from_column]]) <- attributes(dt[[from_column]])
  attributes(result[[to_column]]) <- attributes(dt[[to_column]])
  data.table::setcolorder(
    result,
    c(id_column, "Difference", from_column, to_column,
      characteristic_beg_columns, characteristic_end_columns)
  )

  result
}


#' Calculate Customer Relationship Timeline with pure data.table
#'
#' Pure `data.table` implementation of [calculate_customer_timeline()] that
#' uses grouped cumulative maxima and per-period aggregation instead of Rcpp.
#' Intended for benchmarking and implementation comparison.
#'
#' @inheritParams calculate_customer_timeline
#' @return A data.table with merged periods matching
#'   [calculate_customer_timeline()].
#' @export
calculate_customer_timeline_data_table <- function(data_frame,
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
  run_customer_timeline(
    data_frame = data_frame,
    gap_threshold = gap_threshold,
    id_column = id_column,
    from_column = from_column,
    to_column = to_column,
    characteristic_beg_columns = characteristic_beg_columns,
    characteristic_end_columns = characteristic_end_columns,
    keep_all_periods = keep_all_periods,
    verbose = verbose,
    output_columns = output_columns,
    include_gap_column = include_gap_column,
    copy_data = copy_data,
    merge_fun = merge_relationship_periods_data_table_impl
  )
}
