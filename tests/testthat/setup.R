# This file is required by testthat to set up the test environment

library(testthat)

if (!"package:customerRelationship" %in% search()) {
  if (requireNamespace("customerRelationship", quietly = TRUE)) {
    library(customerRelationship)
  } else if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(testthat::test_path("..", ".."),
                      export_all = FALSE, helpers = FALSE, quiet = TRUE)
  } else {
    stop("Neither customerRelationship nor pkgload is available for test setup.")
  }
}
