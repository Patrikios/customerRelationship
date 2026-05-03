test_that("CustomerTimeline uses default package columns", {
  data <- data.table::data.table(
    ID = c("A", "A"),
    From = as.Date(c("2020-01-01", "2020-01-02")),
    To = as.Date(c("2020-01-01", "2020-01-03")),
    CharacteristicBeg = c("X", "X"),
    CharacteristicEnd1 = c("1", "1"),
    CharacteristicEnd2 = c("Alpha", "Beta")
  )

  processor <- CustomerTimeline(verbose = FALSE)
  result <- calculate_timeline(processor, data)
  expected <- calculate_customer_timeline(
    data,
    id_column = "ID",
    from_column = "From",
    to_column = "To",
    characteristic_beg_columns = "CharacteristicBeg",
    characteristic_end_columns = c("CharacteristicEnd1", "CharacteristicEnd2"),
    verbose = FALSE
  )

  expect_s3_class(result, "data.table")
  expect_equal(result, expected)
})

test_that("CustomerTimeline stores custom column mapping and options", {
  data <- data.table::data.table(
    CustomerID = c("A", "A", "A"),
    StartDate = as.POSIXct(
      c("2020-01-01 10:00:00", "2020-01-01 10:45:00", "2020-01-01 12:00:00"),
      tz = "UTC"
    ),
    EndDate = as.POSIXct(
      c("2020-01-01 10:30:00", "2020-01-01 11:00:00", "2020-01-01 12:30:00"),
      tz = "UTC"
    ),
    StatusBeg = c("Active", "Active", "Active"),
    StatusEnd = c("Checkout", "Checkout", "Support"),
    ChannelEnd = c("Web", "Web", "Phone")
  )

  processor <- CustomerTimeline(
    id_column = "CustomerID",
    from_column = "StartDate",
    to_column = "EndDate",
    characteristic_beg_columns = "StatusBeg",
    characteristic_end_columns = c("StatusEnd", "ChannelEnd"),
    gap_threshold = 30,
    gap_units = "mins",
    keep_all_periods = TRUE,
    output_columns = c("CustomerID", "StartDate", "EndDate", "period_start"),
    verbose = FALSE
  )

  result <- calculate_timeline(processor, data)

  expect_named(result, c("CustomerID", "StartDate", "EndDate", "period_start"))
  expect_equal(nrow(result), 3)
  expect_equal(result$period_start, c(TRUE, FALSE, TRUE))
})

test_that("CustomerTimeline validates configuration", {
  expect_error(CustomerTimeline(id_column = ""), "@id_column")
  expect_error(CustomerTimeline(id_column = c("ID", "Other")), "@id_column")
  expect_error(CustomerTimeline(from_column = c("From", "Start")), "@from_column")
  expect_error(CustomerTimeline(to_column = c("To", "End")), "@to_column")
  expect_error(CustomerTimeline(gap_threshold = -1), "@gap_threshold")
  expect_error(CustomerTimeline(gap_units = "weeks"), "@gap_units")
  expect_error(CustomerTimeline(time_class = "clock"), "@time_class")
  expect_error(CustomerTimeline(verbose = c(TRUE, FALSE)), "@verbose")
})
