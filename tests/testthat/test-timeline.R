timeline_implementations <- list(
  rcpp = calculate_customer_timeline,
  base = calculate_customer_timeline_base,
  data_table = calculate_customer_timeline_data_table
)

expect_same_timeline <- function(actual, expected, info = NULL) {
  expect_identical(names(actual), names(expected), info = info)

  for (col in names(expected)) {
    expect_equal(actual[[col]], expected[[col]], info = paste(info, col))
  }
}

expect_all_implementations_match <- function(input, ..., expected = NULL) {
  if (is.null(expected)) {
    expected <- calculate_customer_timeline(data.table::copy(input), ..., verbose = FALSE)
  }

  for (implementation_name in names(timeline_implementations)) {
    implementation_fun <- timeline_implementations[[implementation_name]]
    actual <- implementation_fun(data.table::copy(input), ..., verbose = FALSE)
    expect_same_timeline(
      actual = actual,
      expected = expected,
      info = paste("implementation:", implementation_name)
    )
  }
}

expect_matches_legacy <- function(input, ...) {
  legacy_env <- new.env(parent = globalenv())
  legacy_path <- testthat::test_path("..", "..", "endvers.R")
  if (!file.exists(legacy_path)) {
    legacy_path <- system.file("extdata", "endvers.R", package = "customerRelationship")
  }
  source(legacy_path, local = legacy_env)

  legacy_result <- suppressMessages(
    suppressWarnings(legacy_env$CustomerRelationshipTimeline(data.table::copy(input)))
  )
  expect_all_implementations_match(input, ..., expected = legacy_result)
}

validate_customer_data_internal <- function(...) {
  getFromNamespace("validate_customer_data", "customerRelationship")(...)
}

test_that("validate_customer_data accepts valid data with custom columns", {
  valid_data <- data.frame(
    CustomerID = c("A", "B"),
    StartDate = as.Date(c("2020-01-01", "2020-01-02")),
    EndDate = as.Date(c("2020-01-03", "2020-01-04")),
    StatusBeg = c("X", "Y"),
    StatusEnd = c("1", "2"),
    TypeEnd = c("Alpha", "Beta")
  )

  expect_true(validate_customer_data_internal(
    valid_data,
    id_column = "CustomerID",
    from_column = "StartDate",
    to_column = "EndDate",
    characteristic_beg_columns = "StatusBeg",
    characteristic_end_columns = c("StatusEnd", "TypeEnd")
  ))
})

test_that("validate_customer_data rejects missing columns", {
  invalid_data <- data.frame(
    ID = c("A", "B"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-03", "2020-01-04"))
  )

  expect_error(validate_customer_data_internal(invalid_data), "Missing required columns")
})

test_that("validate_customer_data rejects empty data", {
  empty_data <- data.frame(
    ID = character(),
    From = as.Date(character()),
    To = as.Date(character()),
    CharacteristicBeg = character(),
    CharacteristicEnd1 = character(),
    CharacteristicEnd2 = character()
  )

  expect_error(validate_customer_data_internal(empty_data), "Input data is empty")
})

test_that("validate_customer_data rejects non-data.frame input", {
  expect_error(validate_customer_data_internal(list(a = 1, b = 2)), "must be a data.frame")
})

test_that("calculate_customer_timeline merges adjacent periods", {
  # Periods with 1-day gap should merge
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-01", "2020-01-03")),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  result <- calculate_customer_timeline(data, verbose = FALSE)

  expect_equal(nrow(result), 1)
  expect_equal(result$ID, "A")
  expect_equal(result$From, as.Date("2020-01-01"))
  expect_equal(result$To, as.Date("2020-01-03"))
  expect_equal(result$CharacteristicBeg, "X")
  expect_equal(result$CharacteristicEnd2, "Beta")
})

test_that("calculate_customer_timeline separates distant periods", {
  # Periods with >1 day gap should be separate
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-05")),
    To = as.Date(c("2020-01-01", "2020-01-10")),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  result <- calculate_customer_timeline(data, verbose = FALSE)

  expect_equal(nrow(result), 2)
  expect_equal(result$ID, c("A", "A"))
  expect_equal(result$From, as.Date(c("2020-01-01", "2020-01-05")))
  expect_equal(result$To, as.Date(c("2020-01-01", "2020-01-10")))
})

test_that("calculate_customer_timeline handles multiple customers", {
  data <- data.table::data.table(
    ID = c("A", "A", "B", "B"),
    From = as.Date(c("2020-01-01", "2020-01-10", "2020-02-01", "2020-02-10")),
    To = as.Date(c("2020-01-05", "2020-01-15", "2020-02-05", "2020-02-15")),
    CharacteristicBeg = c("X", "X", "Y", "Y"),
    CharacteristicEnd1 = c("1", "1", "2", "2"),
    CharacteristicEnd2 = c("Alpha", "Beta", "Gamma", "Delta")
  )

  result <- calculate_customer_timeline(data, verbose = FALSE)

  expect_equal(nrow(result), 4)
  expect_equal(result[, .N, by = ID]$N, c(2L, 2L))
})

test_that("calculate_customer_timeline coerces string dates", {
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = c("2020-01-01", "2020-01-06"),
    To = c("2020-01-05", "2020-01-15"),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  result <- calculate_customer_timeline(data, verbose = FALSE)

  # Should have 1 result
  expect_equal(nrow(result), 1)
  expect_true(inherits(result$From, "Date"))
  expect_true(inherits(result$To, "Date"))
})

test_that("calculate_customer_timeline does not mutate data.frame input when copy_data is TRUE", {
  data <- data.frame(
    ID = c("A", "A"),
    From = c("2020-01-01", "2020-01-04"),
    To = c("2020-01-03", "2020-01-10"),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta"),
    stringsAsFactors = FALSE
  )

  result <- calculate_customer_timeline(data, verbose = FALSE, copy_data = TRUE)

  expect_equal(nrow(result), 1)
  expect_false(data.table::is.data.table(data))
  expect_false(inherits(data$From, "Date"))
  expect_false(inherits(data$To, "Date"))
})

test_that("calculate_customer_timeline preserves beginning characteristics", {
  # When periods merge, beginning characteristics should stay from first period
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-01", "2020-01-05")),
    CharacteristicBeg = c("First", "Second"),  # Should preserve "First"
    CharacteristicEnd1 = c("Type1", "Type2"),  # Should take "Type2"
    CharacteristicEnd2 = c("Cat_A", "Cat_B")   # Should take "Cat_B"
  )

  result <- calculate_customer_timeline(data, keep_all_periods = TRUE, verbose = FALSE)

  # Should have 1 result (merged period)
  expect_equal(nrow(result), 1)
  expect_equal(result$CharacteristicBeg, "First")  # Preserved from first period
  expect_equal(result$CharacteristicEnd1, "Type2") # Taken from last period
  expect_equal(result$CharacteristicEnd2, "Cat_B") # Taken from last period
})

test_that("calculate_customer_timeline works with custom column names", {
  data <- data.table::data.table(
    CustomerID = c("A", "A"),
    StartDate = c("2020-01-01", "2020-01-04"),
    EndDate = c("2020-01-03", "2020-01-10"),
    StatusBeg = c("New", "New"),
    StatusEnd = c("Active", "Active"),
    TypeBeg = c("Basic", "Basic"),
    TypeEnd = c("Basic", "Premium")
  )

  result <- calculate_customer_timeline(
    data,
    id_column = "CustomerID",
    from_column = "StartDate",
    to_column = "EndDate",
    characteristic_beg_columns = c("StatusBeg", "TypeBeg"),
    characteristic_end_columns = c("StatusEnd", "TypeEnd"),
    verbose = FALSE
  )

  # Should have 1 merged result
  expect_equal(nrow(result), 1)
  expect_equal(result$CustomerID, "A")
  expect_equal(result$StatusBeg, "New")    # Beginning characteristic preserved
  expect_equal(result$TypeEnd, "Premium") # Ending characteristic updated
})

test_that("calculate_customer_timeline respects gap_threshold", {
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-05")),
    To = as.Date(c("2020-01-03", "2020-01-10")),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  # With gap_threshold = 1, should have 1 result (gap of 2 days)
  result1 <- calculate_customer_timeline(data, gap_threshold = 1, verbose = FALSE)
  expect_equal(nrow(result1), 2)

  # With gap_threshold = 5, should have 0 results (gap of 2 days <= 5)
  result5 <- calculate_customer_timeline(data, gap_threshold = 5, verbose = FALSE)
  expect_equal(nrow(result5), 1)
})

test_that("calculate_customer_timeline keep_all_periods parameter works", {
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-05")),
    To = as.Date(c("2020-01-03", "2020-01-10")),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  # keep_all_periods = FALSE (default)
  result_filtered <- calculate_customer_timeline(data, keep_all_periods = FALSE, verbose = FALSE)
  expect_false("Difference" %in% names(result_filtered))
  expect_equal(nrow(result_filtered), 2)

  # keep_all_periods = TRUE
  result_all <- calculate_customer_timeline(data, keep_all_periods = TRUE, verbose = FALSE)
  expect_true("Difference" %in% names(result_all))
  expect_equal(nrow(result_all), 2)
  expect_equal(result_all[2, Difference], 2)  # Gap between periods
})

test_that("calculate_customer_timeline matches legacy endvers.R output", {
  input <- data.table::data.table(
    ID = c("A", "A", "A", "B", "B", "C"),
    From = as.Date(c("2020-01-01", "2020-01-02", "2020-01-10",
                     "2020-02-01", "2020-02-04", "2020-03-01")),
    To = as.Date(c("2020-01-01", "2020-01-05", "2020-01-12",
                   "2020-02-02", "2020-02-06", "2020-03-05")),
    CharacteristicBeg = c("X", "X", "X", "Y", "Y", "Z"),
    CharacteristicEnd1 = c("1", "1", "2", "3", "3", "4"),
    CharacteristicEnd2 = c("Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta")
  )

  expect_matches_legacy(input)
})

test_that("all implementations match with custom columns and options", {
  data <- data.table::data.table(
    CustomerID = c("A", "A", "A", "B"),
    StartDate = c("2020-01-01", "2020-01-04", "2020-01-08", "2020-02-01"),
    EndDate = c("2020-01-03", "2020-01-06", "2020-01-09", "2020-02-05"),
    StatusBeg = c("New", "New", "Existing", "New"),
    StatusEnd = c("Open", "Open", "Closed", "Open"),
    TypeBeg = c("Basic", "Basic", "Premium", "Basic"),
    TypeEnd = c("Basic", "Gold", "Gold", "Basic")
  )

  expect_all_implementations_match(
    data,
    gap_threshold = 2,
    id_column = "CustomerID",
    from_column = "StartDate",
    to_column = "EndDate",
    characteristic_beg_columns = c("StatusBeg", "TypeBeg"),
    characteristic_end_columns = c("StatusEnd", "TypeEnd"),
    keep_all_periods = TRUE,
    include_gap_column = TRUE
  )
})

test_that("all implementations preserve default coercion semantics", {
  data <- data.table::data.table(
    ID = c(1L, 1L),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-01", "2020-01-05")),
    CharacteristicBeg = c("A", "B"),
    CharacteristicEnd1 = c(1L, 2L),
    CharacteristicEnd2 = c(10L, 20L)
  )

  expect_all_implementations_match(data, keep_all_periods = TRUE)
})

test_that("calculate_customer_timeline matches legacy endvers.R output on extended fixture", {
  dat_cols <- list(
    ID = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L,
           1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L,
           1L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L,
           2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L,
           2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L,
           2L, 2L, 2L, 2L, 2L, 2L, 2L, 2L, 3L, 3L, 3L, 3L, 4L, 4L, 4L, 5L,
           5L, 5L, 6L, 7L, 7L, 7L),
    From = structure(
      c(10859, 12039, 14102, 14782, 14783, 14784, 14785, 14786, 14789, 14791,
        14792, 14793, 14795, 14796, 14797, 14798, 14799, 14800, 14803, 14807,
        14811, 14817, 14818, 14820, 14821, 14824, 14827, 14828, 14834, 14835,
        14838, 14841, 14845, 10859, 10862, 10865, 10865, 10865, 12084, 12084,
        12084, 12084, 12658, 13421, 14761, 14863, 14863, 14863, 14863, 14863,
        14888, 14973, 14980, 14980, 14980, 14980, 14980, 14980, 14993, 14994,
        14998, 15009, 15051, 15355, 15355, 15355, 15358, 15358, 15358, 15358,
        15358, 15387, 15387, 15388, 15388, 16416, 16452, 16464, 16478, 16478,
        16974, 17116, 17116, 17122, 17122, 17522, 14316, 14471, 14563, 15608,
        10865, 17709, 17737, 13027, 14473, 17190, 10859, 10865, 15219, 16736),
      class = "Date",
      tzone = "Europe/Berlin"
    ),
    To = structure(
      c(14781, 15339, 15964, 14782, 14783, 14784, 14785, 14788, 14790, 14791,
        14792, 14794, 14795, 14796, 14797, 14798, 14799, 14802, 14806, 14810,
        14816, 14817, 14819, 14820, 14823, 14826, 14827, 14833, 14834, 14837,
        14840, 14844, 14846, 14979, 14979, 14979, 14979, 14979, 14979, 15354,
        14972, 14862, 14760, 15354, 14993, 15354, 15354, 15354, 15354, 15354,
        15354, 14992, 15354, 15354, 15354, 15354, 15354, 15354, 14997, 15354,
        15008, 15050, 15354, 16415, 15386, 15357, 15386, 2932896, 16973,
        2932896, 2932896, 15387, 15387, 16451, 16463, 2932896, 16477, 16477,
        17115, 17115, 2932896, 17121, 17121, 2932896, 17521, 2932896, 14329,
        14562, 15064, 15621, 15886, 17709, 17737, 17189, 14533, 17256, 15430,
        15399, 15227, 2932896),
      class = "Date",
      tzone = "Europe/Berlin"
    ),
    CharacteristicBeg = c(
      "f", "a", "b", "f", "f", "f", "f", "f", "f", "f", "f", "f", "f", "f",
      "f", "f", "f", "f", "f", "f", "f", "f", "f", "b", "b", "b", "b", "b",
      "b", "b", "b", "b", "b", "a", "a", "a", "a", "a", "a", "a", "a", "a",
      "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a",
      "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a",
      "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a",
      "a", "a", "a", "b", "b", "b", "a", "c", "c", "a", "d", "a", "a", "a",
      "b", "e"
    ),
    CharacteristicEnd1 = c(
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, 5L, NA, 5L, 5L, 5L, 5L, 5L, 5L,
      NA, NA, 5L, 5L, 5L, 5L, 5L, NA, 5L, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, 1L, 2L, 3L, 1L, 3L, 2L, NA, NA, 2L, 3L, 3L, 6L, 1L, NA, NA, NA
    ),
    CharacteristicEnd2 = c(
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA,
      NA, NA, NA, NA, NA, NA, 2L, 2L, NA, NA, NA, NA, NA, NA, NA, NA, NA
    )
  )

  common_len <- min(vapply(dat_cols, length, integer(1)))
  dat <- as.data.frame(
    lapply(dat_cols, function(x) x[seq_len(common_len)]),
    stringsAsFactors = FALSE
  )

  expect_matches_legacy(dat)
})
