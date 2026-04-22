#' Pure base R period merge implementation
#'
#' @noRd
merge_relationship_periods_base_impl <- function(dtable,
                                               id_column,
                                               from_column,
                                               to_column,
                                               characteristic_beg_columns,
                                               characteristic_end_columns,
                                               gap_threshold,
                                               keep_all_periods) {
  id_values <- as.character(dtable[[id_column]])
  from_values <- dtable[[from_column]]
  to_values <- dtable[[to_column]]
  difference <- rep.int(NA_integer_, length(id_values))

  beg_values <- setNames(
    lapply(characteristic_beg_columns, function(col) as.character(dtable[[col]])),
    characteristic_beg_columns
  )
  end_values <- setNames(
    lapply(characteristic_end_columns, function(col) as.character(dtable[[col]])),
    characteristic_end_columns
  )

  marker <- 1L
  if (length(id_values) > 1L) {
    for (i in 2:length(id_values)) {
      same_customer <- isTRUE(id_values[i] == id_values[i - 1L])

      if (!same_customer) {
        marker <- i
      } else {
        difference[i] <- as.integer(from_values[i] - to_values[marker])

        if (!is.na(difference[i]) && difference[i] > gap_threshold) {
          marker <- i
        } else if (isTRUE(to_values[i] > to_values[marker])) {
          to_values[marker] <- to_values[i]

          for (col in characteristic_end_columns) {
            end_values[[col]][marker] <- end_values[[col]][i]
          }
        }
      }
    }
  }

  result <- data.table::as.data.table(
    c(
      setNames(list(id_values), id_column),
      list(Difference = difference),
      setNames(list(from_values), from_column),
      setNames(list(to_values), to_column)
    )
  )

  for (col in characteristic_beg_columns) {
    data.table::set(result, j = col, value = beg_values[[col]])
  }

  for (col in characteristic_end_columns) {
    data.table::set(result, j = col, value = end_values[[col]])
  }

  result
}


#' Calculate Customer Relationship Timeline with pure base R
#'
#' Pure base R implementation of [calculate_customer_timeline()] that uses a
#' vector-based merge loop mirroring the Rcpp algorithm. Intended for
#' benchmarking and implementation comparison.
#'
#' @inheritParams calculate_customer_timeline
#' @return A data.table with merged periods matching
#'   [calculate_customer_timeline()].
#' @export
calculate_customer_timeline_base <- function(data_frame,
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
    merge_fun = merge_relationship_periods_base_impl
  )
}

