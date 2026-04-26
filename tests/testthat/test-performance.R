if (!exists("extended_legacy_fixture", mode = "function")) {
  source(testthat::test_path("helper-extended-fixture.R"))
}

test_that("calculate_customer_timeline processes 1M heterogeneous rows quickly", {
  fixture <- data.table::as.data.table(extended_legacy_fixture())
  target_rows <- 1000000L
  repeats <- ceiling(target_rows / nrow(fixture))

  input <- fixture[rep(seq_len(.N), repeats)][seq_len(target_rows)]
  block_id <- rep(seq_len(repeats), each = nrow(fixture))[seq_len(target_rows)]
  row_id <- seq_len(target_rows)
  id_pool <- 20000L
  synthetic_id <- ((as.integer(input$ID) * 7919L + block_id * 104729L +
    row_id * 37L) %% id_pool) + 1L
  from_offset <- as.integer((block_id * 17L + row_id * 3L) %% 1825L)
  duration_delta <- as.integer((block_id + row_id) %% 11L) - 5L

  input[
    ,
    `:=`(
      ID = sprintf("CUS%05d", synthetic_id),
      From = From + from_offset,
      To = pmax(From + from_offset, To + from_offset + duration_delta),
      CharacteristicBeg = paste0(CharacteristicBeg, "_", block_id %% 11L),
      CharacteristicEnd1 = ifelse(
        is.na(CharacteristicEnd1),
        NA_character_,
        paste0("end1_", CharacteristicEnd1, "_", block_id %% 7L)
      ),
      CharacteristicEnd2 = ifelse(
        is.na(CharacteristicEnd2),
        NA_character_,
        paste0("end2_", CharacteristicEnd2, "_", row_id %% 13L)
      )
    )
  ]
  set.seed(42)
  input <- input[sample.int(.N)]

  start_time <- Sys.time()
  result <- calculate_customer_timeline(input, verbose = TRUE)
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  expect_s3_class(result, "data.table")
  expect_equal(nrow(input), target_rows)
  expect_gt(nrow(result), 0L)
  expect_lt(elapsed, 10)
})
