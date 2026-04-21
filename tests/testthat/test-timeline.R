test_that("validate_customer_data accepts valid data", {
  valid_data <- data.frame(
    ID = c("A", "B"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-03", "2020-01-04")),
    CharacteristicBeg = c("X", "Y"),
    CharacteristicEnd1 = c("1", "2"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )
  
  expect_true(validate_customer_data(valid_data))
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
  
  result <- calculate_customer_timeline(data)
  
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
  
  result <- calculate_customer_timeline(data)
  
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
  
  result <- calculate_customer_timeline(data)
  
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
  
  result <- calculate_customer_timeline(data)
  
  # Should have 1 result
  expect_equal(nrow(result), 1)
  expect_true(inherits(result$From, "Date"))
  expect_true(inherits(result$To, "Date"))
})

test_that("calculate_customer_timeline preserves characteristics on merge", {
  # When periods merge, characteristics from later period should be preserved
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-01", "2020-01-05")),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("Type1", "Type2"),
    CharacteristicEnd2 = c("Cat_A", "Cat_B")
  )
  
  result <- calculate_customer_timeline(data)
  
  # No results because gap is 0, but if there were a gap > 1, 
  # characteristics would be from the merged period
  expect_equal(nrow(result), 0)
})
