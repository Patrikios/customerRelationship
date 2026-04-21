test_that("validate_customer_data accepts valid data with custom columns", {
  valid_data <- data.frame(
    CustomerID = c("A", "B"),
    StartDate = as.Date(c("2020-01-01", "2020-01-02")),
    EndDate = as.Date(c("2020-01-03", "2020-01-04")),
    StatusBeg = c("X", "Y"),
    StatusEnd = c("1", "2"),
    TypeEnd = c("Alpha", "Beta")
  )

  expect_true(validate_customer_data(valid_data,
                                   id_column = "CustomerID",
                                   from_column = "StartDate",
                                   to_column = "EndDate",
                                   characteristic_beg_columns = "StatusBeg",
                                   characteristic_end_columns = c("StatusEnd", "TypeEnd")))
})

test_that("validate_customer_data rejects missing columns", {
  invalid_data <- data.frame(
    ID = c("A", "B"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-03", "2020-01-04"))
  )

  expect_error(validate_customer_data(invalid_data), "Missing required columns")
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

  expect_error(validate_customer_data(empty_data), "Input data is empty")
})

test_that("validate_customer_data rejects non-data.frame input", {
  expect_error(validate_customer_data(list(a = 1, b = 2)), "must be a data.frame")
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

  # Should have no results because gap is 0 (adjacent)
  expect_equal(nrow(result), 0)
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

  # Should have 1 result (the second period with gap > 1)
  expect_equal(nrow(result), 1)
  expect_equal(result$ID, "A")
  expect_equal(result$From, as.Date("2020-01-05"))
  expect_equal(result$To, as.Date("2020-01-10"))
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

  # Both customers should have periods with gaps > 1
  expect_equal(nrow(result), 2)
  expect_true(all(c("A", "B") %in% result$ID))
})

test_that("calculate_customer_timeline coerces string dates", {
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = c("2020-01-01", "2020-01-10"),
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
    StartDate = c("2020-01-01", "2020-01-05"),
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

  # Should have 1 result
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
  expect_equal(nrow(result1), 1)

  # With gap_threshold = 5, should have 0 results (gap of 2 days <= 5)
  result5 <- calculate_customer_timeline(data, gap_threshold = 5, verbose = FALSE)
  expect_equal(nrow(result5), 0)
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

  # keep_all_periods = TRUE
  result_all <- calculate_customer_timeline(data, keep_all_periods = TRUE, verbose = FALSE)
  expect_true("Difference" %in% names(result_all))
  expect_equal(result_all[2, Difference], 2)  # Gap between periods
})
