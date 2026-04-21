# customerRelationship

[![R-CMD-check](https://github.com/yourusername/customerRelationship/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/customerRelationship/actions)

An R package for efficiently processing customer relationship data to identify and merge consecutive periods with minimal gaps. Built with **Rcpp** for high-performance C++ computing and **data.table** for scalable data manipulation.

## Overview

This package calculates the overall customer relationship timeline per customer from many fragmented activity inputs. It is particularly useful for CRMs with fragmented data (e.g., SAP, Salesforce). It transforms smaller fragments of orders/positions into continuous periods where the subject has been active without a day pause in relationship.

## Use Cases

Perfect for marketing analysts interested in:
- Overall length of relationships between customers and company
- Customer loyalty outcomes of campaigns
- Customer tenure calculation
- Churn/survival analysis
- Other relationship-based marketing applications

## Features

- **High Performance**: C++ implementation via Rcpp for fast period merging
- **Scalable**: Uses data.table for efficient memory management with large datasets
- **Clean API**: Simple, well-documented functions for customer timeline processing
- **Validated Input**: Automatic data validation and type coercion
- **Informative**: Timing information and record counts in output

## Installation

### Prerequisites

- R >= 4.0.0
- C++14 compatible compiler (Rtools for Windows, Xcode for macOS, gcc for Linux)

### From GitHub

```r
devtools::install_github("yourusername/customerRelationship")
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

### `calculate_customer_timeline(dtable, ...)`

Process customer relationship data and merge consecutive periods with gaps ≤ gap_threshold.

**Parameters:**
- `dtable`: A data.frame or data.table with customer relationship records
- `gap_threshold`: Maximum gap (in days) between periods to merge (default: 1)
- `id_column`: Name of the customer ID column (default: "ID")
- `from_column`: Name of the start date column (default: "From")
- `to_column`: Name of the end date column (default: "To")
- `characteristic_beg_columns`: Column names that should preserve beginning values (default: "CharacteristicBeg")
- `characteristic_end_columns`: Column names that should take ending values (default: c("CharacteristicEnd1", "CharacteristicEnd2"))
- `keep_all_periods`: If TRUE, return all periods including merged ones (default: FALSE)
- `verbose`: If TRUE, print processing time and result summary (default: TRUE)
- `output_columns`: Columns to include in output. If NULL, includes all relevant columns (default: NULL)
- `include_gap_column`: If TRUE and keep_all_periods is TRUE, include the Difference column (default: TRUE)
- `copy_data`: If TRUE, work on a copy of the input data (default: TRUE)

**Returns:**
A data.table with merged periods

**Output Columns:**
- ID column (name specified by id_column)
- From column (name specified by from_column)
- To column (name specified by to_column)
- Beginning characteristic columns (preserve first period values)
- Ending characteristic columns (take last period values)
- Difference: Gap in days to previous period (only when keep_all_periods = TRUE and include_gap_column = TRUE)

### `validate_customer_data(dtable, ...)`

Validate input data structure before processing.

**Parameters:**
- `dtable`: A data.frame or data.table to validate
- `id_column`: Name of the ID column (default: "ID")
- `from_column`: Name of the From date column (default: "From")
- `to_column`: Name of the To date column (default: "To")
- `characteristic_beg_columns`: Column names for beginning characteristics
- `characteristic_end_columns`: Column names for ending characteristics

**Returns:**
Invisibly returns TRUE if valid

**Raises:**
- Error if required columns are missing
- Error if data is empty
- Error if input is not a data.frame

## Algorithm

The package implements a sophisticated period-merging algorithm:

1. **Sorts** records by customer ID and start date
2. **Iterates** through sorted records, tracking each customer's current period
3. **Calculates** the gap (in days) between consecutive periods for the same customer
4. **Merges** periods if the gap is ≤ 1 day by:
   - Extending the current period's end date
   - Updating characteristics to the later period's values
5. **Filters** output to show only periods with gaps > 1 day (distinct relationships)

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

### Building from Source

```bash
# Windows/macOS/Linux
R CMD build customerRelationship
R CMD check customerRelationship_*.tar.gz
```

## License

MIT License - see LICENSE file for details

## Author

Patrik

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Troubleshooting

### "Error: could not find function 'merge_relationship_periods'"

Make sure to rebuild the package to compile the C++ code:
```r
devtools::load_all()
```


