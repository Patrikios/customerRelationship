# customerRelationship

An R package for efficiently processing customer relationship data, or more generic, iterval data, to identify and merge consecutive periods with minimal gaps. Built with **Rcpp** for better performance using C++ computing and **data.table** for scalable data manipulation.

## Overview

In essence, the package exists in order to calculate the overall customer relationship timeline per customer from many fragmented activity inputs. It is particularly useful for CRMs with fragmented data such as SAP or Salesforce. It transforms smaller fragments of orders or positions into continuous periods where the subject has been active without a meaningful pause in relationship.

## Choose Your Time Granularity

The package now supports two related timeline styles:

| Input type | Best for | Continuity rule | Example threshold |
| --- | --- | --- | --- |
| `Date` | tenure, churn, lifecycle, campaign attribution | treat gaps in whole days | `gap_threshold = 1` |
| `POSIXct` | sessions, handoffs, SLA windows, intraday journeys | treat gaps in seconds, minutes, or hours | `gap_threshold = 30, gap_units = "mins"` |

That means you can use the same package to answer both "how long has this customer been active overall?" and "which events belong to the same session or operational window?"

## Use Cases

The package is best understood as an interval-collapsing engine: it merges overlapping or near-adjacent fragments into continuous periods.

### Date-Based Collapsing

Best when continuity is measured in whole days and the collapsed result represents a relationship span:

- Customer tenure and lifecycle duration
- Subscription, contract, membership, or account active spans
- Churn, lapse, and reactivation windows
- Campaign exposure and loyalty analysis
- Coverage, entitlement, or status ranges

### Datetime-Based Collapsing

Best when continuity is measured within the day and the collapsed result represents an episode or operational window:

- Session stitching for web, app, or product behavior
- Call-center, support, or ownership handoff windows
- SLA coverage and escalation timelines
- Machine uptime or downtime episodes
- Logistics, fulfillment, or delivery event windows
- Same-day pause-and-return behavior

## Features

- **Solid Performance**: C++ implementation via Rcpp for fast period merging
- **Scalable**: Uses data.table for efficient memory management with large datasets
- **Clean API**: Simple, well-documented functions for customer timeline processing
- **Validated Input**: Automatic data validation and type coercion
- **Flexible Time Granularity**: Handles both day-level `Date` ranges and intra-day `POSIXct` timelines
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
  StatusBeg = c("New", "New", "Returning"),
  StatusEnd = c("Active", "Active", "Active"),
  TypeBeg = c("Basic", "Basic", "Premium"),
  TypeEnd = c("Basic", "Premium", "Gold")
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

# Datetime timelining with a 30-minute continuity window
events <- data.table(
  ID = c("CUS001", "CUS001", "CUS001"),
  From = as.POSIXct(
    c("2020-01-01 10:00:00", "2020-01-01 10:45:00", "2020-01-01 12:00:00"),
    tz = "UTC"
  ),
  To = as.POSIXct(
    c("2020-01-01 10:30:00", "2020-01-01 11:00:00", "2020-01-01 12:30:00"),
    tz = "UTC"
  ),
  CharacteristicBeg = c("Active", "Active", "Active"),
  CharacteristicEnd1 = c("Checkout", "Checkout", "Support"),
  CharacteristicEnd2 = c("Web", "Web", "Phone")
)

session_timeline <- calculate_customer_timeline(
  events,
  gap_threshold = 30,
  gap_units = "mins"
)
print(session_timeline)
```

## Function Reference

### `calculate_customer_timeline(data_frame, ...)`

Process customer relationship data and merge consecutive periods with gaps <= `gap_threshold`.

**Parameters:**
- `data_frame`: A data.frame or data.table with customer relationship records
- `gap_threshold`: Maximum gap between periods to merge. Numeric values are interpreted as days by default, preserving the legacy API. For datetime workflows you can also pass `difftime` values or combine numeric thresholds with `gap_units`. A new period starts only when `From - previous To > gap_threshold`. (default: 1 day)
- `gap_units`: Units for numeric `gap_threshold` values. One of `"auto"`, `"days"`, `"hours"`, `"mins"`, or `"secs"` (default: `"auto"`)
- `id_column`: Name of the customer ID column (default: `"ID"`)
- `from_column`: Name of the start date column (default: `"From"`)
- `to_column`: Name of the end date column (default: `"To"`)
- `time_class`: One of `"auto"`, `"date"`, or `"datetime"` to control whether the package preserves daily or intra-day granularity (default: `"auto"`)
- `characteristic_beg_columns`: Column names that should preserve beginning values (default: `"CharacteristicBeg"`)
- `characteristic_end_columns`: Column names that should take ending values (default: `c("CharacteristicEnd1", "CharacteristicEnd2")`)
- `keep_all_periods`: If TRUE, keep the internal gap diagnostics in the returned merged periods (default: FALSE)
- `verbose`: If TRUE, print processing time and result summary (default: TRUE)
- `output_columns`: Columns to include in output. If NULL, includes all relevant columns (default: NULL)
- `include_gap_column`: If TRUE and `keep_all_periods` is TRUE, include the `Difference` column (default: TRUE)
- `copy_data`: If TRUE, work on a copy of the input data; if FALSE, work on the input object directly without copying it (default: TRUE)

**Returns:**
A data.table with merged periods

**Output Columns:**
- ID column (name specified by `id_column`)
- From column (name specified by `from_column`)
- To column (name specified by `to_column`)
- Beginning characteristic columns (preserve first period values)
- Ending characteristic columns (take last period values)
- Difference: Gap to previous period. Returned in days for `Date` timelines and as `difftime` seconds for datetime timelines when `keep_all_periods = TRUE` and `include_gap_column = TRUE`

## Merge Semantics

The continuity rule is simple:

- A new period starts only when `From - previous To > gap_threshold`
- Overlapping periods merge automatically
- Back-to-back periods merge when the gap is within the threshold
- The first period keeps beginning characteristics, while the last merged fragment contributes ending characteristics

## Algorithm

The package implements a period-merging algorithm:

1. **Sorts** records by customer ID and start time
2. **Iterates** through sorted records, tracking each customer's current merged period
3. **Calculates** the gap between consecutive periods for the same customer
4. **Merges** periods if the gap is less than or equal to `gap_threshold` by:
   - Extending the current period's end
   - Updating ending characteristics to the later period's values
5. **Returns** one row per merged period, with optional gap diagnostics when `keep_all_periods = TRUE`

## Timelining Ideas

The package started as a daily relationship engine, but it becomes much richer when you preserve time-of-day:

- **Daily tenure timelines**: the original CRM use case where continuity means "no break of more than 1 day"
- **Session stitching**: merge browsing, app, or call-center activity windows separated by only a few minutes
- **Same-day reactivation**: distinguish a return within 2 hours from a return next week
- **SLA coverage**: track support ownership, escalation windows, or response continuity inside one business day
- **Stateful journeys**: compress event logs into phases like onboarding, active use, pause, and reactivation

That gives the package two complementary modes: `Date` for lifecycle and tenure questions, and `POSIXct` for true timeline reconstruction.

## Performance

- **Compilation**: C++ code is pre-compiled into the package
- **Memory**: Efficient with data.table's reference semantics
- **Speed**: Typically processes 1M+ records in seconds on modern hardware

## Development

### Building The Package

```r
# Generate documentation from roxygen comments
devtools::document()

# Check package
devtools::check()

# Run tests
devtools::test()
```

### Building From Source

```bash
# Windows/macOS/Linux
R CMD build customerRelationship
R CMD check customerRelationship_*.tar.gz
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.
