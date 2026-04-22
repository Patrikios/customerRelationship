source(testthat::test_path("..", "benchmarks", "benchmark-timeline.R"), local = TRUE)

test_that("timeline benchmark harness runs when enabled", {
  skip_if_not(
    identical(Sys.getenv("RUN_TIMELINE_BENCHMARKS"), "true"),
    "Set RUN_TIMELINE_BENCHMARKS=true to execute benchmark timing."
  )

  benchmark_config <- benchmark_timeline_config_from_env()
  benchmark_data <- benchmark_timeline_dataset(
    n_customers = benchmark_config$n_customers,
    periods_per_customer = benchmark_config$periods_per_customer,
    seed = benchmark_config$seed
  )

  benchmark_result <- run_timeline_benchmark(
    data = benchmark_data,
    iterations = benchmark_config$iterations,
    gap_threshold = benchmark_config$gap_threshold,
    keep_all_periods = benchmark_config$keep_all_periods,
    implementations = benchmark_config$implementations
  )

  cat(paste(format_timeline_benchmark_summary(benchmark_result), collapse = "\n"), "\n")

  expect_equal(sort(benchmark_result$summary$implementation),
               sort(benchmark_config$implementations))
  expect_true(all(benchmark_result$timings$elapsed_seconds >= 0))
  expect_equal(
    benchmark_result$input_rows,
    as.integer(benchmark_config$n_customers * benchmark_config$periods_per_customer)
  )
})
