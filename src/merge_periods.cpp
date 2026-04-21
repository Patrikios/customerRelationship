#include <Rcpp.h>
using namespace Rcpp;

//' Merge Customer Relationship Periods
//'
//' C++ implementation for merging consecutive customer relationship periods.
//' Groups records by customer ID and merges consecutive periods if the gap
//' between them is 1 day or less.
//'
//' @param dtable A DataFrame with customer relationship records
//' @return DataFrame with merged periods and gap calculations
//'
//' @keywords internal
// [[Rcpp::export]]
DataFrame merge_relationship_periods(DataFrame dtable) {
  int marker = 0;
  
  CharacterVector ID = dtable["ID"];
  CharacterVector CharacteristicBeg = dtable["CharacteristicBeg"];
  CharacterVector CharacteristicEnd1 = dtable["CharacteristicEnd1"];
  CharacterVector CharacteristicEnd2 = dtable["CharacteristicEnd2"];
  DateVector From = dtable["From"];
  DateVector To = dtable["To"];
  
  IntegerVector Difference(ID.size(), 9999);
  
  // Process each record
  for (int i = 1; i < ID.size(); i++) {
    // New customer ID encountered
    if (ID[i] != ID[i-1]) {
      marker = i;
    } else {
      // Same customer - calculate gap between current and marker period
      Difference[i] = From[i] - To[marker];
      
      // If gap > 1, start new period
      if (Difference[i] > 1) {
        marker = i;
      }
      // If gap <= 1, merge by extending marker period
      else if (To[i] > To[marker]) {
        To[marker] = To[i];
        CharacteristicEnd1[marker] = CharacteristicEnd1[i];
        CharacteristicEnd2[marker] = CharacteristicEnd2[i];
      }
    }
  }
  
  // Create and return output DataFrame
  return DataFrame::create(
    _["ID"] = ID,
    _["Difference"] = Difference,
    _["From"] = From,
    _["To"] = To,
    _["CharacteristicBeg"] = CharacteristicBeg,
    _["CharacteristicEnd1"] = CharacteristicEnd1,
    _["CharacteristicEnd2"] = CharacteristicEnd2,
    _["stringsAsFactors"] = false
  );
}
