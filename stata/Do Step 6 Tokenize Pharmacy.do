//Flash-Zerai data set
//This snippet of code breaks up the single pharmacy file, which is too large to merge, into ~147 bite size chunks
//12-16-2014

forvalues counter=1(1)$MaxNumDrugs {
use "Data Pharmacy $DateOfAnalysis.dta", clear
keep studyid cdmcode`counter' cdpdrugcode`counter' ARTDate`counter' BIDDrug`counter' SinglePillRegimen`counter' DrugName`counter' DrugConstituents`counter' CDMDescription`counter'
save Pharmacy`counter'.dta, replace
}

clear
