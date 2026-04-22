benchmark_script_path <- function() {
  file_arg <- "--file="
  script_arg <- commandArgs(trailingOnly = FALSE)
  file_entry <- script_arg[grepl(paste0("^", file_arg), script_arg)]

  if (length(file_entry) == 0L) {
    return(NULL)
  }

  normalizePath(sub(file_arg, "", file_entry[1L]), winslash = "/", mustWork = FALSE)
}


benchmark_timeline_dataset <- function(n_customers = 2500L,
                                       periods_per_customer = 12L,
                                       seed = 42L) {
  stopifnot(n_customers > 0L, periods_per_customer > 0L)

  set.seed(seed)

  total_rows <- as.integer(n_customers * periods_per_customer)
  ids <- sprintf("CUS%06d", rep(seq_len(n_customers), each = periods_per_customer))

  from <- as.Date("2020-01-01") + integer(total_rows)
  to <- as.Date("2020-01-01") + integer(total_rows)
  characteristic_beg <- character(total_rows)
  characteristic_end1 <- character(total_rows)
  characteristic_end2 <- character(total_rows)

  row_index <- 1L
  for (customer_idx in seq_len(n_customers)) {
    current_start <- sample.int(365L, 1L) - 1L

    for (period_idx in seq_len(periods_per_customer)) {
      duration <- sample.int(10L, 1L)
      gap <- sample(c(0L, 1L, 2L, 5L, 10L), size = 1L, prob = c(0.35, 0.3, 0.2, 0.1, 0.05))

      current_start <- current_start + gap
      from[row_index] <- as.Date("2020-01-01") + current_start
      to[row_index] <- from[row_index] + duration
      characteristic_beg[row_index] <- paste0("B", (customer_idx + period_idx) %% 7L)
      characteristic_end1[row_index] <- paste0("E", duration %% 5L)
      characteristic_end2[row_index] <- paste0("G", gap)

      current_start <- current_start + duration
      row_index <- row_index + 1L
    }
  }

  data.table::data.table(
    ID = ids,
    From = from,
    To = to,
    CharacteristicBeg = characteristic_beg,
    CharacteristicEnd1 = characteristic_end1,
    CharacteristicEnd2 = characteristic_end2
  )
}


benchmark_timeline_defaults <- function() {
  list(
    n_customers = 5000L,
    periods_per_customer = 20L,
    iterations = 3L,
    gap_threshold = 1L,
    keep_all_periods = TRUE,
    seed = 42L,
    implementations = c("rcpp", "base", "data_table")
  )
}


benchmark_timeline_implementations <- function() {
  list(
    rcpp = calculate_customer_timeline,
    base = calculate_customer_timeline_base,
    data_table = calculate_customer_timeline_data_table
  )
}


parse_benchmark_implementations <- function(value,
                                            default = benchmark_timeline_defaults()$implementations) {
  if (is.null(value) || !nzchar(value)) {
    return(default)
  }

  implementations <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  implementations <- implementations[nzchar(implementations)]

  available <- names(benchmark_timeline_implementations())
  invalid <- setdiff(implementations, available)
  if (length(invalid) > 0L) {
    stop(
      "Unknown benchmark implementations: ",
      paste(invalid, collapse = ", "),
      ". Valid values are: ",
      paste(available, collapse = ", "),
      call. = FALSE
    )
  }

  unique(implementations)
}


benchmark_timeline_config_from_env <- function() {
  defaults <- benchmark_timeline_defaults()

  read_int_env <- function(name, default) {
    value <- Sys.getenv(name, unset = "")
    if (!nzchar(value)) {
      return(as.integer(default))
    }

    parsed <- suppressWarnings(as.integer(value))
    if (is.na(parsed) || parsed <= 0L) {
      stop("Environment variable ", name, " must be a positive integer.", call. = FALSE)
    }

    parsed
  }

  list(
    n_customers = read_int_env("TIMELINE_BENCHMARK_CUSTOMERS", defaults$n_customers),
    periods_per_customer = read_int_env("TIMELINE_BENCHMARK_PERIODS", defaults$periods_per_customer),
    iterations = read_int_env("TIMELINE_BENCHMARK_ITERATIONS", defaults$iterations),
    gap_threshold = read_int_env("TIMELINE_BENCHMARK_GAP_THRESHOLD", defaults$gap_threshold),
    keep_all_periods = identical(Sys.getenv("TIMELINE_BENCHMARK_KEEP_ALL_PERIODS", "true"), "true"),
    seed = read_int_env("TIMELINE_BENCHMARK_SEED", defaults$seed),
    implementations = parse_benchmark_implementations(
      Sys.getenv("TIMELINE_BENCHMARK_IMPLEMENTATIONS", unset = ""),
      default = defaults$implementations
    )
  )
}


run_timeline_benchmark <- function(data,
                                   iterations = 5L,
                                   gap_threshold = 1L,
                                   keep_all_periods = FALSE,
                                   verify_equal = TRUE,
                                   implementations = c("rcpp", "base", "data_table")) {
  stopifnot(iterations > 0L)

  implementation_map <- benchmark_timeline_implementations()
  implementations <- parse_benchmark_implementations(
    paste(implementations, collapse = ","),
    default = names(implementation_map)
  )
  implementation_map <- implementation_map[implementations]

  if (verify_equal) {
    reference_name <- if ("rcpp" %in% names(implementation_map)) "rcpp" else names(implementation_map)[1L]
    reference <- implementation_map[[reference_name]](
      data.table::copy(data),
      gap_threshold = gap_threshold,
      keep_all_periods = keep_all_periods,
      verbose = FALSE
    )

    for (implementation_name in setdiff(names(implementation_map), reference_name)) {
      candidate <- implementation_map[[implementation_name]](
        data.table::copy(data),
        gap_threshold = gap_threshold,
        keep_all_periods = keep_all_periods,
        verbose = FALSE
      )

      if (!identical(names(candidate), names(reference))) {
        stop("Benchmark aborted: column mismatch for implementation ", implementation_name, call. = FALSE)
      }

      for (col in names(reference)) {
        if (!isTRUE(all.equal(candidate[[col]], reference[[col]]))) {
          stop("Benchmark aborted: result mismatch for implementation ", implementation_name,
               " in column ", col, call. = FALSE)
        }
      }
    }
  }

  timing_rows <- vector("list", length(implementation_map) * iterations)
  timing_index <- 1L

  for (implementation_name in names(implementation_map)) {
    implementation_fun <- implementation_map[[implementation_name]]

    for (iteration in seq_len(iterations)) {
      gc(FALSE)
      elapsed <- unname(system.time(
        implementation_fun(
          data.table::copy(data),
          gap_threshold = gap_threshold,
          keep_all_periods = keep_all_periods,
          verbose = FALSE
        )
      )[["elapsed"]])

      timing_rows[[timing_index]] <- data.table::data.table(
        implementation = implementation_name,
        iteration = iteration,
        elapsed_seconds = elapsed
      )
      timing_index <- timing_index + 1L
    }
  }

  timings <- data.table::rbindlist(timing_rows)
  summary <- timings[
    ,
    .(
      iterations = .N,
      min_seconds = min(elapsed_seconds),
      median_seconds = stats::median(elapsed_seconds),
      mean_seconds = mean(elapsed_seconds),
      max_seconds = max(elapsed_seconds)
    ),
    by = implementation
  ][order(mean_seconds)]

  list(
    input_rows = nrow(data),
    implementations = names(implementation_map),
    timings = timings,
    summary = summary
  )
}


format_timeline_benchmark_summary <- function(benchmark_result) {
  c(
    sprintf("Rows: %s", format(benchmark_result$input_rows, big.mark = ",")),
    capture.output(print(benchmark_result$summary))
  )
}


print_timeline_benchmark_summary <- function(benchmark_result) {
  cat(paste(format_timeline_benchmark_summary(benchmark_result), collapse = "\n"), "\n")
}


if (sys.nframe() == 0L) {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required to run this benchmark script.", call. = FALSE)
  }

  script_path <- benchmark_script_path()
  if (is.null(script_path)) {
    stop("Unable to determine the benchmark script path.", call. = FALSE)
  }

  pkg_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/")
  pkgload::load_all(pkg_root, quiet = TRUE)

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

  print_timeline_benchmark_summary(benchmark_result)
}
