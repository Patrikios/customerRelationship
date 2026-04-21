#include <Rcpp.h>
using namespace Rcpp;

//' Merge Customer Relationship Periods
//'
//' C++ implementation for merging consecutive customer relationship periods.
//' Groups records by customer ID and merges consecutive periods if the gap
//' between them is 1 day or less.
//'
//' @param dtable A DataFrame with customer relationship records
//' @param id_column Name of the ID column
//' @param from_column Name of the From date column
//' @param to_column Name of the To date column
//' @param characteristic_beg_columns Character vector of column names that preserve beginning values
//' @param characteristic_end_columns Character vector of column names that take ending values
//' @return DataFrame with merged periods and gap calculations
//'
//' @keywords internal
// [[Rcpp::export]]
DataFrame merge_relationship_periods(DataFrame dtable,
                                   std::string id_column,
                                   std::string from_column,
                                   std::string to_column,
                                   CharacterVector characteristic_beg_columns,
                                   CharacterVector characteristic_end_columns,
                                   int gap_threshold,
                                   bool keep_all_periods) {
  int marker = 0;

  CharacterVector ID = dtable[id_column];
  DateVector From = dtable[from_column];
  DateVector To = dtable[to_column];

  IntegerVector Difference(ID.size(), NA_INTEGER);

  // Create vectors for all characteristic columns
  std::vector<CharacterVector> beg_chars;
  std::vector<CharacterVector> end_chars;

  // Extract beginning characteristic columns
  for (int k = 0; k < characteristic_beg_columns.size(); k++) {
    beg_chars.push_back(dtable[as<std::string>(characteristic_beg_columns[k])]);
  }

  // Extract ending characteristic columns
  for (int k = 0; k < characteristic_end_columns.size(); k++) {
    end_chars.push_back(dtable[as<std::string>(characteristic_end_columns[k])]);
  }

  // Process each record
  for (int i = 1; i < ID.size(); i++) {
    // New customer ID encountered
    if (ID[i] != ID[i-1]) {
      marker = i;
    } else {
      // Same customer - calculate gap between current and marker period
      Difference[i] = From[i] - To[marker] - 1;  // Number of gap days

      // If gap > 1, start new period
      if (Difference[i] > 1) {
        marker = i;
      }
      // If gap <= 1, merge by extending marker period
      else if (To[i] > To[marker]) {
        To[marker] = To[i];

        // Update ending characteristics from the current period
        for (size_t k = 0; k < end_chars.size(); k++) {
          end_chars[k][marker] = end_chars[k][i];
        }
        // Beginning characteristics stay from the marker (first) period
      }
    }
  }

  // Build the output DataFrame
  List result_list = List::create(
    Named(id_column) = ID,
    Named("Difference") = Difference,
    Named(from_column) = From,
    Named(to_column) = To
  );

  // Add beginning characteristics
  for (int k = 0; k < characteristic_beg_columns.size(); k++) {
    result_list.push_back(beg_chars[k], as<std::string>(characteristic_beg_columns[k]));
  }

  // Add ending characteristics
  for (int k = 0; k < characteristic_end_columns.size(); k++) {
    result_list.push_back(end_chars[k], as<std::string>(characteristic_end_columns[k]));
  }

  // Create DataFrame
  DataFrame result = DataFrame(result_list);
  result.attr("stringsAsFactors") = false;
  return result;
}
