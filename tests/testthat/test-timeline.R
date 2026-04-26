expect_matches_legacy <- function(input) {
  legacy_env <- new.env(parent = globalenv())
  legacy_path <- testthat::test_path("..", "..", "endvers.R")
  if (!file.exists(legacy_path)) {
    legacy_path <- system.file("extdata", "endvers.R", package = "customerRelationship")
  }
  source(legacy_path, local = legacy_env)

  legacy_result <- suppressMessages(
    suppressWarnings(legacy_env$CustomerRelationshipTimeline(data.table::copy(input)))
  )
  package_result <- calculate_customer_timeline(data.table::copy(input), verbose = FALSE)

  expect_identical(names(package_result), names(legacy_result))

  for (col in names(package_result)) {
    expect_equal(package_result[[col]], legacy_result[[col]])
  }
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

test_that("calculate_customer_timeline preserves POSIXct timelines", {
  data <- data.table::data.table(
    ID = c("A", "A", "A"),
    From = as.POSIXct(
      c("2020-01-01 10:00:00", "2020-01-01 10:45:00", "2020-01-01 12:00:00"),
      tz = "UTC"
    ),
    To = as.POSIXct(
      c("2020-01-01 10:30:00", "2020-01-01 11:00:00", "2020-01-01 12:30:00"),
      tz = "UTC"
    ),
    CharacteristicBeg = c("X", "X", "X"),
    CharacteristicEnd1 = c("1", "1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta", "Gamma")
  )

  result <- calculate_customer_timeline(
    data,
    gap_threshold = 30,
    gap_units = "mins",
    keep_all_periods = TRUE,
    verbose = FALSE
  )

  expect_equal(nrow(result), 3)
  expect_true(inherits(result$From, "POSIXct"))
  expect_true(inherits(result$To, "POSIXct"))
  expect_equal(result$From[1], as.POSIXct("2020-01-01 10:00:00", tz = "UTC"))
  expect_equal(result$To[1], as.POSIXct("2020-01-01 11:00:00", tz = "UTC"))
  expect_equal(result$CharacteristicEnd2[1], "Beta")
  expect_true(inherits(result$Difference, "difftime"))
  expect_equal(as.numeric(result$Difference[2], units = "secs"), 900)
  expect_equal(as.numeric(result$Difference[3], units = "secs"), 3600)
})

test_that("calculate_customer_timeline auto-detects character datetimes", {
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = c("2020-01-01 10:00:00", "2020-01-01 10:20:00"),
    To = c("2020-01-01 10:10:00", "2020-01-01 10:40:00"),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  result <- calculate_customer_timeline(
    data,
    gap_threshold = as.difftime(15, units = "mins"),
    verbose = FALSE
  )

  expect_equal(nrow(result), 1)
  expect_true(inherits(result$From, "POSIXct"))
  expect_true(inherits(result$To, "POSIXct"))
  expect_equal(result$CharacteristicEnd2, "Beta")
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

  result <- calculate_customer_timeline(data, verbose = FALSE)

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
    ID = c("A", "A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-02", "2020-01-10")),
    To = as.Date(c("2020-01-01", "2020-01-03", "2020-01-12")),
    CharacteristicBeg = c("X", "X", "X"),
    CharacteristicEnd1 = c("1", "1", "2"),
    CharacteristicEnd2 = c("Alpha", "Beta", "Gamma")
  )

  # keep_all_periods = FALSE (default)
  result_filtered <- calculate_customer_timeline(data, keep_all_periods = FALSE, verbose = FALSE)
  expect_false("Difference" %in% names(result_filtered))
  expect_equal(nrow(result_filtered), 2)

  # keep_all_periods = TRUE
  result_all <- calculate_customer_timeline(data, keep_all_periods = TRUE, verbose = FALSE)
  expect_true("Difference" %in% names(result_all))
  expect_true("period_start" %in% names(result_all))
  expect_equal(nrow(result_all), 3)
  expect_equal(result_all[, Difference], c(NA_integer_, 1L, 7L))
  expect_equal(result_all[, period_start], c(TRUE, FALSE, TRUE))

  result_selected <- calculate_customer_timeline(
    data,
    keep_all_periods = TRUE,
    include_gap_column = FALSE,
    output_columns = c("ID", "From", "period_start"),
    verbose = FALSE
  )
  expect_named(result_selected, c("ID", "From", "period_start"))
  expect_equal(result_selected[, period_start], c(TRUE, FALSE, TRUE))
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

test_that("calculate_customer_timeline matches legacy endvers.R output on extended fixture", {
  dat <- extended_legacy_fixture()
  expect_matches_legacy(dat)
})
