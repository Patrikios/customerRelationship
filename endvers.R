CustomerRelationshipTimeline <- function(dtable)
{
  if(!require(Rcpp)){install.packages("Rcpp"); library(Rcpp)}
  if(!require(data.table)){install.packages("data.table"); library(data.table)}
  suppressPackageStartupMessages(if(!require(anytime)) install.packages("anytime"))
  
  cppFunction('DataFrame BezRcpp(DataFrame dtable) {

              int marker = 0;
              CharacterVector ID = dtable["ID"];
              CharacterVector CharacteristicBeg = dtable["CharacteristicBeg"];
              CharacterVector CharacteristicEnd1 = dtable["CharacteristicEnd1"];
              CharacterVector CharacteristicEnd2 = dtable["CharacteristicEnd2"]; 
              DateVector From = dtable["From"];
              DateVector To = dtable["To"];
              IntegerVector Difference(ID.size(), 9999);
              
              for (int i = 1; i < ID.size(); i++) {
                if(ID[i] != ID[i-1]) {
                  marker = i;
                } else {
                  Difference[i] = From[i] - To[marker];
                  if(Difference[i]>1) marker = i;
                    else if(To[i]>To[marker]){
                      To[marker] = To[i];
                      CharacteristicEnd1[marker] = CharacteristicEnd1[i];
                      CharacteristicEnd2[marker] = CharacteristicEnd2[i];
              }
              }
              }
              
              // create a new data frame
              return DataFrame::create(
                  _["ID"] = ID,
                  _["Difference"] = Difference,
                  _["From"] = From,
                  _["To"] = To,
                  _["CharacteristicBeg"] = CharacteristicBeg,
                  _["CharacteristicEnd1"] = CharacteristicEnd1,
                  _["CharacteristicEnd2"] = CharacteristicEnd2,
                  _["stringsAsFactors"] = false);
            }'
  )
  
  continuum_kunde_Rcpp_ <- function(dtable){
    A <- Sys.time()
    if(! "data.table" %in% class(dtable)) setDT(dtable)
    if(class(dtable[["From"]])!="Date" || class(dtable[["To"]])!="Date") for (j in c("From", "To")) set(dtable, j = j, value = anytime::anydate(dtable[[j]])) 
    setorder(dtable, ID, From)
    dt <- setDT(BezRcpp(copy(dtable)))
    dt <- dt[Difference>1, .(ID, From, To, CharacteristicBeg, CharacteristicEnd1, CharacteristicEnd2)]
    B <- Sys.time()
    print(paste0("Customer relationship timeline calculated in ", round(difftime(B, A, units = "secs"), 1), " secs. A data.table was produced."))
    return(dt)
  }
  
  return(continuum_kunde_Rcpp_(dtable))
}
