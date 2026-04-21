# Example usage of customerRelationship package

# Install and load package
# devtools::install()
library(customerRelationship)
library(data.table)

# Example 1: Basic customer timeline
cat("Example 1: Basic Customer Timeline\n")
cat("===================================\n\n")

# Create sample data
sample_data <- data.table(
  ID = c("CUS001", "CUS001", "CUS001", "CUS002", "CUS002", "CUS003"),
  From = as.Date(c(
    "2020-01-01", "2020-01-02", "2020-02-05",
    "2020-01-10", "2020-03-01",
    "2020-06-15"
  )),
  To = as.Date(c(
    "2020-01-01", "2020-01-03", "2020-02-10",
    "2020-01-15", "2020-03-10",
    "2020-06-20"
  )),
  CharacteristicBeg = c("Active", "Active", "Active", "Active", "Active", "Active"),
  CharacteristicEnd1 = c("Type1", "Type1", "Type1", "Type2", "Type1", "Type1"),
  CharacteristicEnd2 = c("Cat_A", "Cat_B", "Cat_C", "Cat_A", "Cat_B", "Cat_D")
)

cat("Input data (6 records, 3 customers):\n")
print(sample_data)
cat("\n")

# Validate and process
cat("Processing customer timeline...\n\n")
result <- calculate_customer_timeline(sample_data)

cat("\nOutput timeline (distinct periods):\n")
print(result)

cat("\n\nExplanation:\n")
cat("- CUS001: Records 1-2 merged (1 day gap) -> single period until 2020-01-03\n")
cat("          Record 3 is separate (32 day gap) -> second period\n")
cat("- CUS002: Record 1 stands alone (59 day gap until record 2)\n")
cat("- CUS003: Single record, no merging needed\n")

cat("\n\n")
cat("Example 2: Custom column names with multiple characteristics\n")
cat("=============================================================\n\n")

# Example with custom column names and multiple characteristics
sample_data_2 <- data.table(
  CustomerID = c("A", "A", "A", "B", "B"),
  StartDate = c("2021-01-01", "2021-01-02", "2021-01-10", "2021-02-01", "2021-02-15"),
  EndDate = c("2021-01-01", "2021-01-05", "2021-01-15", "2021-02-10", "2021-02-20"),
  StatusBeg = c("New", "New", "New", "Returning", "Returning"),        # Beginning status
  StatusEnd = c("Active", "Active", "Active", "Active", "Active"),     # Ending status
  TypeBeg = c("Basic", "Basic", "Basic", "Premium", "Premium"),        # Beginning type
  TypeEnd = c("Basic", "Premium", "Gold", "Premium", "Gold"),          # Ending type
  RegionBeg = c("North", "North", "North", "South", "South"),          # Beginning region
  RegionEnd = c("North", "North", "West", "South", "East")             # Ending region
)

cat("Input data with custom columns and multiple characteristics:\n")
print(sample_data_2)
cat("\n")

# Process with custom column specifications
result_2 <- calculate_customer_timeline(
  sample_data_2,
  id_column = "CustomerID",
  from_column = "StartDate",
  to_column = "EndDate",
  characteristic_beg_columns = c("StatusBeg", "TypeBeg", "RegionBeg"),
  characteristic_end_columns = c("StatusEnd", "TypeEnd", "RegionEnd"),
  keep_all_periods = TRUE,  # Show all periods including merged ones
  verbose = TRUE
)

cat("\nOutput with all periods (including merged ones):\n")
print(result_2)

cat("\n\nExplanation:\n")
cat("- Customer A: Records 1-2 merged (1 day gap), Record 3 separate (5 day gap)\n")
cat("- Beginning characteristics (StatusBeg, TypeBeg, RegionBeg) preserve first period values\n")
cat("- Ending characteristics (StatusEnd, TypeEnd, RegionEnd) take last period values\n")
cat("- Difference column shows gap to previous period\n")

cat("\n\n")
cat("Example 3: Different gap threshold and column selection\n")
cat("======================================================\n\n")

# Same data but with 7-day gap threshold and selected output columns
result_3 <- calculate_customer_timeline(
  sample_data_2,
  gap_threshold = 7,  # Merge periods with gaps <= 7 days
  id_column = "CustomerID",
  from_column = "StartDate",
  to_column = "EndDate",
  characteristic_beg_columns = c("StatusBeg", "TypeBeg", "RegionBeg"),
  characteristic_end_columns = c("StatusEnd", "TypeEnd", "RegionEnd"),
  output_columns = c("CustomerID", "StartDate", "EndDate", "StatusBeg", "TypeEnd"),  # Select specific columns
  verbose = TRUE
)

cat("Output with 7-day gap threshold and selected columns:\n")
print(result_3)

cat("\n\nExplanation:\n")
cat("- With 7-day threshold, Customer A's records 2-3 are now merged (5 day gap)\n")
cat("- Only selected columns are returned: CustomerID, StartDate, EndDate, StatusBeg, TypeEnd\n")
cat("- Beginning characteristics (StatusBeg) preserve first period values\n")
cat("- Ending characteristics (TypeEnd) take last period values\n")
