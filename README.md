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

# Create sample data
data <- data.table(
  ID = c("CUS001", "CUS001", "CUS001", "CUS002", "CUS002"),
  From = as.Date(c("2020-01-01", "2020-01-02", "2020-02-01", 
                   "2020-01-15", "2020-02-01")),
  To = as.Date(c("2020-01-01", "2020-01-03", "2020-02-05", 
                 "2020-01-20", "2020-02-10")),
  CharacteristicBeg = c("Active", "Active", "Active", "Active", "Active"),
  CharacteristicEnd1 = c("Type1", "Type1", "Type1", "Type1", "Type1"),
  CharacteristicEnd2 = c("Cat_A", "Cat_B", "Cat_B", "Cat_C", "Cat_C")
)

# Validate data structure
validate_customer_data(data)

# Calculate customer timeline
result <- calculate_customer_timeline(data)

# View results
print(result)
```

## Function Reference

### `calculate_customer_timeline(dtable)`

Process customer relationship data and merge consecutive periods with gaps ≤ 1 day.

**Parameters:**
- `dtable`: A data.frame or data.table with customer relationship records

**Required Columns:**
- `ID`: Customer identifier
- `From`: Period start date
- `To`: Period end date
- `CharacteristicBeg`: Beginning characteristic
- `CharacteristicEnd1`: First ending characteristic
- `CharacteristicEnd2`: Second ending characteristic

**Returns:** 
A data.table with merged periods and gap calculations

**Output Columns:**
- `ID`: Customer identifier
- `From`: Period start date
- `To`: Period end date (may be extended from merge)
- `CharacteristicBeg`: Beginning characteristic
- `CharacteristicEnd1`: First ending characteristic (updated from merge)
- `CharacteristicEnd2`: Second ending characteristic (updated from merge)
- `Difference`: Gap in days to previous period (> 1 indicates separate period)

### `validate_customer_data(dtable)`

Validate input data structure before processing.

**Parameters:**
- `dtable`: A data.frame or data.table to validate

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


