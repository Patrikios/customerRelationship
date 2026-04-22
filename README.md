# customerRelationship

An R package for efficiently processing customer relationship data to identify and merge consecutive periods with minimal gaps. Built with **Rcpp** for high-performance C++ computing and **data.table** for scalable data manipulation.

## Overview

In essense, the package exists in order to calculate the overall customer relationship timeline per customer from many fragmented activity inputs. It is particularly useful for CRMs with fragmented data (e.g., SAP, Salesforce). It transforms smaller fragments of orders/positions into continuous periods where the subject has been active without a day pause in relationship.

## Benchmarking Branch Note

The `benchmarking` branch extends the package with:

- Benchmark coverage for comparing alternative implementations
- A pure base R implementation: `calculate_customer_timeline_base()`
- A pure `data.table` implementation: `calculate_customer_timeline_data_table()`
- An opt-in benchmark test harness for timing `rcpp`, `base`, and `data.table`

## Use Cases

Suitable for customer analysis:
- Overall and cumulative length of relationships between customers and company
- Customer loyalty outcomes of campaigns
- Customer tenure calculation
- Churn/survival analysis
- Other relationship-based marketing applications

## Features

- **High Performance**: C++ implementation via Rcpp for fast period merging
- **Benchmark Variants**: Pure base R and pure `data.table` alternatives for implementation comparison
- **Scalable**: Uses data.table for efficient memory management with large datasets
- **Clean API**: Simple, well-documented functions for customer timeline processing
- **Validated Input**: Automatic data validation and type coercion
- **Informative**: Execution timing information and record counts in output

## Installation

### Prerequisites

- R >= 4.0.0
- C++14 compatible compiler (Rtools for Windows, Xcode for macOS, gcc for Linux)

### From GitHub

```r
devtools::install_github("patrikios/customerRelationship")
```

### Local Installation

```r
# Set working directory to package root
devtools::load_all()
# Or build and install
devtools::install()
```

## Quick Start

```r
library(customerRelationship)
library(data.table)

# Basic usage with default column names
data <- data.table(
  ID = c("CUS001", "CUS001", "CUS001", "CUS002"),
  From = as.Date(c("2020-01-01", "2020-01-02", "2020-02-01", "2020-01-15")),
  To = as.Date(c("2020-01-01", "2020-01-03", "2020-02-05", "2020-01-20")),
  CharacteristicBeg = c("Active", "Active", "Active", "Active"),
  CharacteristicEnd1 = c("Type1", "Type1", "Type1", "Type1"),
  CharacteristicEnd2 = c("Cat_A", "Cat_B", "Cat_B", "Cat_C")
)

timeline <- calculate_customer_timeline(data)
print(timeline)

# Custom column names with multiple characteristics
data2 <- data.table(
  CustomerID = c("A", "A", "B"),
  StartDate = c("2020-01-01", "2020-01-02", "2020-02-01"),
  EndDate = c("2020-01-01", "2020-01-03", "2020-02-05"),
  StatusBeg = c("New", "New", "Returning"),    # Beginning status
  StatusEnd = c("Active", "Active", "Active"), # Ending status
  TypeBeg = c("Basic", "Basic", "Premium"),    # Beginning type
  TypeEnd = c("Basic", "Premium", "Gold")      # Ending type
)

timeline2 <- calculate_customer_timeline(
  data2,
  id_column = "CustomerID",
  from_column = "StartDate", 
  to_column = "EndDate",
  characteristic_beg_columns = c("StatusBeg", "TypeBeg"),
  characteristic_end_columns = c("StatusEnd", "TypeEnd")
)
print(timeline2)
```

## Function Reference

### `calculate_customer_timeline(data_frame, ...)`

Process customer relationship data and merge consecutive periods with gaps ≤ gap_threshold.

**Parameters:**
- `data_frame`: A data.frame or data.table with customer relationship records
- `gap_threshold`: Maximum gap (in days) between periods to merge. That is, maximum allowed difference between the start date of a period and the end date of the previous period for both periods to be merged into one continuous relationship period. A new period starts only when From - previous To > gap_threshold. (default: 1)
- `id_column`: Name of the customer ID column (default: "ID")
- `from_column`: Name of the start date column (default: "From")
- `to_column`: Name of the end date column (default: "To")
- `characteristic_beg_columns`: Column names that should preserve beginning values (default: "CharacteristicBeg")
- `characteristic_end_columns`: Column names that should take ending values (default: c("CharacteristicEnd1", "CharacteristicEnd2"))
- `keep_all_periods`: If TRUE, keep the internal gap diagnostics in the returned merged periods (default: FALSE)
- `verbose`: If TRUE, print processing time and result summary (default: TRUE)
- `output_columns`: Columns to include in output. If NULL, includes all relevant columns (default: NULL)
- `include_gap_column`: If TRUE and keep_all_periods is TRUE, include the Difference column (default: TRUE)
- `copy_data`: If TRUE, work on a copy of the input data, if not works on the data.frame directly without copying it (default: TRUE)

**Returns:**
A data.table with merged periods

### `calculate_customer_timeline_base(data_frame, ...)`

Pure base R implementation of the same timeline logic. This is intended mainly for benchmarking and implementation comparison.

### `calculate_customer_timeline_data_table(data_frame, ...)`

Pure `data.table` implementation of the same timeline logic. This is intended mainly for benchmarking and implementation comparison.

**Output Columns:**
- ID column (name specified by id_column)
- From column (name specified by from_column)
- To column (name specified by to_column)
- Beginning characteristic columns (preserve first period values)
- Ending characteristic columns (take last period values)
- Difference: Gap in days to previous period (only when keep_all_periods = TRUE and include_gap_column = TRUE)

## Algorithm

The package implements a fairly sophisticated period-merging algorithm:

1. **Sorts** records by customer ID and start date
2. **Iterates** through sorted records, tracking each customer's current period
3. **Calculates** the gap (in days) between consecutive periods for the same customer
4. **Merges** periods if the gap is less than or equal to `gap_threshold` by:
   - Extending the current period's end date
   - Updating characteristics to the later period's values
5. **Returns** one row per merged period, with optional gap diagnostics when `keep_all_periods = TRUE`

## Performance

- **Compilation**: C++ code is pre-compiled into the package
- **Memory**: Efficient with data.table's reference semantics
- **Speed**: Typically processes 1M+ records in seconds on modern hardware

## Development

### Building the Package

```r
# Generate documentation from roxygen comments
devtools::document()

# Check package
devtools::check()

# Run tests
devtools::test()
```

### Benchmark Testing

The benchmark harness is opt-in. Regular test runs do not execute the timing benchmark unless explicitly enabled.

Standard tests only:

```r
devtools::test()
```

Run benchmark tests for all 3 implementations:

```r
Sys.setenv(RUN_TIMELINE_BENCHMARKS = "true")
devtools::test()
```

Run benchmark tests only for `rcpp` and `data.table`:

```r
Sys.setenv(RUN_TIMELINE_BENCHMARKS = "true")
Sys.setenv(TIMELINE_BENCHMARK_IMPLEMENTATIONS = "rcpp,data_table")
devtools::test()
```

Configure the benchmark dataset and iteration count:

```r
Sys.setenv(RUN_TIMELINE_BENCHMARKS = "true")
Sys.setenv(TIMELINE_BENCHMARK_CUSTOMERS = "5000")
Sys.setenv(TIMELINE_BENCHMARK_PERIODS = "20")
Sys.setenv(TIMELINE_BENCHMARK_ITERATIONS = "3")
devtools::test()
```

The default benchmark setup in this branch uses:

- `5,000` customers
- `20` periods per customer
- `100,000` total rows
- `3` timing iterations per implementation

Run the benchmark script directly without the full test suite:

```r
Rscript tests/benchmarks/benchmark-timeline.R
```

Available benchmark environment variables:

- `RUN_TIMELINE_BENCHMARKS`
- `TIMELINE_BENCHMARK_IMPLEMENTATIONS`
- `TIMELINE_BENCHMARK_CUSTOMERS`
- `TIMELINE_BENCHMARK_PERIODS`
- `TIMELINE_BENCHMARK_ITERATIONS`
- `TIMELINE_BENCHMARK_GAP_THRESHOLD`
- `TIMELINE_BENCHMARK_KEEP_ALL_PERIODS`
- `TIMELINE_BENCHMARK_SEED`

Valid values for `TIMELINE_BENCHMARK_IMPLEMENTATIONS` are:

- `rcpp`
- `base`
- `data_table`

### Building from Source

```bash
# Windows/macOS/Linux
R CMD build customerRelationship
R CMD check customerRelationship_*.tar.gz
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

