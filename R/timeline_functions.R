#' Validate Customer Relationship Data
#'
#' Checks that input data has the required columns and correct data types
#' for customer timeline processing.
#'
#' @param dtable A data.frame or data.table to validate
#'
#' @return Invisibly returns TRUE if valid, otherwise throws an error
#'
#' @details
#' Required columns:
#' - ID: Customer identifier
#' - CharacteristicBeg: Beginning characteristic
#' - CharacteristicEnd1: First ending characteristic
#' - CharacteristicEnd2: Second ending characteristic
#' - From: Start date (will be coerced to Date class)
#' - To: End date (will be coerced to Date class)
#'
#' @examples
#' \dontrun{
#' data <- data.table::data.table(
#'   ID = c("A", "A", "B"),
#'   From = c("2020-01-01", "2020-01-02", "2020-02-01"),
#'   To = c("2020-01-01", "2020-01-03", "2020-02-05"),
#'   CharacteristicBeg = c("X", "X", "Y"),
#'   CharacteristicEnd1 = c("1", "1", "2"),
#'   CharacteristicEnd2 = c("A", "B", "C")
#' )
#' validate_customer_data(data)
#' }
#'
#' @export
validate_customer_data <- function(dtable) {
  required_cols <- c("ID", "From", "To", "CharacteristicBeg", 
                    "CharacteristicEnd1", "CharacteristicEnd2")
  
  if (!is.data.frame(dtable)) {
    stop("Input must be a data.frame or data.table", call. = FALSE)
  }
  
  missing_cols <- setdiff(required_cols, names(dtable))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "), 
         call. = FALSE)
  }
  
  if (nrow(dtable) == 0) {
    stop("Input data is empty", call. = FALSE)
  }
  
  invisible(TRUE)
}


#' Calculate Customer Relationship Timeline
#'
#' Process customer relationship data to identify and merge consecutive periods
#' with gaps of 1 day or less. Uses Rcpp for efficient C++ processing and 
#' data.table for scalability.
#'
#' @param dtable A data.frame or data.table containing customer relationship data
#'
#' @return A data.table with merged periods, including:
#'   - ID: Customer identifier
#'   - From: Period start date
#'   - To: Period end date
#'   - CharacteristicBeg: Beginning characteristic
#'   - CharacteristicEnd1: First ending characteristic
#'   - CharacteristicEnd2: Second ending characteristic
#'   - Difference: Gap (in days) to previous period for same customer
#'
#' @details
#' The function performs the following operations:
#' 1. Validates input data structure
#' 2. Converts to data.table if necessary
#' 3. Coerces date columns to Date class
#' 4. Sorts by ID and From date
#' 5. Calls C++ merge function to identify and merge periods
#' 6. Filters to keep only periods with gaps > 1 day
#'
#' Processing time is printed to console upon completion.
#'
#' @examples
#' \dontrun{
#' data <- data.table::data.table(
#'   ID = c("CUS001", "CUS001", "CUS001", "CUS002"),
#'   From = as.Date(c("2020-01-01", "2020-01-02", "2020-02-01", "2020-01-15")),
#'   To = as.Date(c("2020-01-01", "2020-01-03", "2020-02-05", "2020-01-20")),
#'   CharacteristicBeg = c("Active", "Active", "Active", "Active"),
#'   CharacteristicEnd1 = c("Type1", "Type1", "Type1", "Type1"),
#'   CharacteristicEnd2 = c("Cat_A", "Cat_B", "Cat_B", "Cat_C")
#' )
#' 
#' timeline <- calculate_customer_timeline(data)
#' print(timeline)
#' }
#'
#' @export
calculate_customer_timeline <- function(dtable) {
  # Validate input
  validate_customer_data(dtable)
  
  # Start timing
  start_time <- Sys.time()
  
  # Convert to data.table if needed
  if (!data.table::is.data.table(dtable)) {
    data.table::setDT(dtable)
  } else {
    dtable <- data.table::copy(dtable)
  }
  
  # Coerce date columns to Date class
  for (col in c("From", "To")) {
    if (!inherits(dtable[[col]], "Date")) {
      data.table::set(dtable, j = col, 
                      value = anytime::anydate(dtable[[col]]))
    }
  }
  
  # Sort by ID and From date
  data.table::setorder(dtable, ID, From)
  
  # Apply Rcpp merge function
  merged_dt <- data.table::setDT(merge_relationship_periods(dtable))
  
  # Filter to gaps > 1 day
  result <- merged_dt[Difference > 1, 
                     .(ID, From, To, CharacteristicBeg, 
                       CharacteristicEnd1, CharacteristicEnd2)]
  
  # End timing and report
  end_time <- Sys.time()
  elapsed <- round(difftime(end_time, start_time, units = "secs"), 1)
  
  message("Customer relationship timeline calculated in ", elapsed, 
          " secs. Returned ", nrow(result), " periods.")
  
  return(result)
}
