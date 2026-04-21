# Example usage of customerRelationship package

# Install and load package
# devtools::install()
library(customerRelationship)
library(data.table)

# Example 1: Simple customer timeline
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
cat("Example 2: Data with date strings\n")
cat("==================================\n\n")

# Example with date strings (automatic conversion)
sample_data_2 <- data.table(
  ID = c("A", "A", "B", "B"),
  From = c("2021-01-01", "2021-01-02", "2021-02-01", "2021-02-10"),
  To = c("2021-01-01", "2021-01-03", "2021-02-05", "2021-02-15"),
  CharacteristicBeg = c("X", "X", "Y", "Y"),
  CharacteristicEnd1 = c("1", "1", "2", "2"),
  CharacteristicEnd2 = c("Alpha", "Beta", "Gamma", "Delta")
)

cat("Input with string dates:\n")
print(sample_data_2)
cat("\n")

result_2 <- calculate_customer_timeline(sample_data_2)

cat("\nMerged periods:\n")
print(result_2)
