//This is the file which merges the pharmacy files in and keeps track of whether individuals are or or not filling the meds in their regimen on a day to day basis.

//First, we open the long form data file:
use "Data ExpandedCD4VLDemo $DateOfAnalysis.dta", clear


//Merge the CurrentRegimen file and drop individuals who never were dispensed medications
merge m:1 studyid using "Data CurrentRegimen $DateOfAnalysis.dta"
tab studyid if _merge==1
drop if _merge==1
drop _merge

//We create the string variable CurrentRegimen which is time-varying and contains the Current Regimen for that date
//We then delete the superfluous CurrentRegimen* variables which are not time-varying:
generate CurrentRegimen=""
generate CurrentRegimenNumber=.
generate NewRegimen=0
generate CurrentBIDRegimen=.
forvalues i=1(1)$MaxNumberRegimens {
decode CurrentRegimen`i', generate(CurrRegimen`i')
replace CurrentRegimen=CurrRegimen`i' if CurrentDate== RegimenStartDate`i'
replace CurrentRegimenNumber=`i' if CurrentDate== RegimenStartDate`i'
replace CurrentBIDRegimen=BIDRegimen`i' if CurrentDate== RegimenStartDate`i'
replace NewRegimen=1 if CurrentDate== RegimenStartDate`i'
drop CurrRegimen`i' CurrentRegimen`i' RegimenStartDate`i' BIDRegimen`i'
}
tab CurrentRegimen
bysort studyid ( CurrentDate): replace CurrentRegimen=CurrentRegimen[_n-1] if CurrentRegimen==""
bysort studyid ( CurrentDate): replace CurrentRegimenNumber=CurrentRegimenNumber[_n-1] if CurrentRegimenNumber==.
bysort studyid ( CurrentDate): replace CurrentBIDRegimen=CurrentBIDRegimen[_n-1] if CurrentBIDRegimen==.

//For each of the initial regimens, we set what the Current Drugs are appropriately:
split CurrentRegimen, parse(/)

forvalues i=1(1)$SizeOfLargestRegimen {
rename CurrentRegimen`i' CurrentDrug`i'Name
generate CurrentDrug`i'CurrentDispense=0
}

//This code merges the Pharmacy fill files with the active database
forvalues counter=1(1)$MaxNumDrugs {
display "Currently on loop iteration " `counter' "..."
merge m:1 studyid using Pharmacy`counter'.dta
drop _merge
decode DrugName`counter', generate(DrugName`counter'Decoded)
forvalues j=1(1)$SizeOfLargestRegimen{
replace CurrentDrug`j'CurrentDispense=30 if ((CurrentDrug`j'Name== DrugName`counter'Decoded)&(CurrentDate== ARTDate`counter'))
}
drop cdmcode`counter' cdpdrugcode`counter' ARTDate`counter' BIDDrug`counter' SinglePillRegimen`counter' CDMDescription`counter' DrugName`counter' DrugConstituents`counter' DrugName`counter'Decoded
}

save "Data Long form merged file $DateOfAnalysis.dta", replace
clear
