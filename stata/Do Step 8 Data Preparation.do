//Flash Zerai analysis
///This is the file which takes the long form merged file and does the final analysis to prepare it for analysis
//6-1-2014 edition

use "Data Long form merged file $DateOfAnalysis.dta", clear

//We use the variable 'M' so that we can identify the first observation in any new regimen
bysort studyid CurrentRegimenNumber (CurrentDate): generate M=_n

//Now we sort again in alphabetical order and use the variable "N" to identify the first observation by individual
sort studyid CurrentDate
by studyid: generate N=_n

//For each of the up to $SizeOfLargestRegimen pills a pt is on, the following code calculates how many pills they should have left that day for the first regimen
forvalues counter=1(1)$SizeOfLargestRegimen {
generate CurrentDrug`counter'PillsLeft= CurrentDrug`counter'CurrentDispense if ((M==1)&(CurrentRegimenNumber==1))
replace CurrentDrug`counter'PillsLeft=cond((CurrentDrug`counter'CurrentDispense==30)&(CurrentDrug`counter'PillsLeft[_n-1]==0),30 ,max(0,CurrentDrug`counter'CurrentDispense+CurrentDrug`counter'PillsLeft[_n-1]-1)) if ((M>1)&(CurrentRegimenNumber==1))
}


//For each of the up to $SizeOfLargestRegimen pills a pt is on, the following code calculates how many pills they should have left that day for the subsequent regimens:
forvalues Regim=2(1)$MaxNumberRegimens{
forvalues counter=1(1)$SizeOfLargestRegimen {
//Credits the patient for the pills dispensed on the first day of the new regimen:
replace CurrentDrug`counter'PillsLeft= CurrentDrug`counter'CurrentDispense if ((M==1)&(CurrentRegimenNumber==`Regim'))
//The next loop credits the patient for any pills from their prior regimen they had left the previous, subtracting the one they would have had to take:
forvalues j=1(1)$SizeOfLargestRegimen {
replace CurrentDrug`counter'PillsLeft=max(0,CurrentDrug`counter'PillsLeft+CurrentDrug`j'PillsLeft[_n-1]-1) if ((M==1)&(CurrentRegimenNumber==`Regim')&(CurrentDrug`counter'Name==CurrentDrug`j'Name[_n-1])&(CurrentDrug`counter'Name~=""))
}
//Adds up dispensed pills and previously given pills (subtracting one) for all observations after the first:
replace CurrentDrug`counter'PillsLeft=cond((CurrentDrug`counter'CurrentDispense==30)&(CurrentDrug`counter'PillsLeft[_n-1]==0),30 ,max(0,CurrentDrug`counter'CurrentDispense+CurrentDrug`counter'PillsLeft[_n-1]-1)) if ((M>1)&(CurrentRegimenNumber==`Regim'))
}
}


//This code calculates the current number of drugs a patient is taking
generate CurrentNumberofDrugs=1
forvalues i=2(1)$SizeOfLargestRegimen {
replace CurrentNumberofDrugs=`i' if CurrentDrug`i'Name~=""
}
replace CurrentNumberofDrugs=0 if CurrentRegimen==""
tab CurrentNumberofDrugs

//This code generates and figures out whether a day is covered
generate DayIsCovered=0
replace DayIsCovered=1 if CurrentDrug1PillsLeft>0
forvalues i=2(1)$SizeOfLargestRegimen {
replace DayIsCovered=0 if ( CurrentDrug`i'PillsLeft==0 & CurrentDrug`i'Name~="")
}
replace DayIsCovered=. if CurrentRegimen==""

//Day is partially covered is defined; it is 1 if a patient is taking an incomplete regimen
generate DayIsPartiallyCovered=0
forvalues i=1(1)$SizeOfLargestRegimen {
replace DayIsPartiallyCovered=1 if ( CurrentDrug`i'PillsLeft>0 & CurrentDrug`i'Name~="")
}
replace DayIsPartiallyCovered=0 if DayIsCovered==1
replace DayIsPartiallyCovered=. if DayIsCovered==.

//We define a variable for a day being fully uncovered:
generate DayIsUncovered=1-DayIsPartiallyCovered-DayIsCovered

//Other outcomes
//We define a patient as being completely lost to follow up if they have no future CD4 or VL being checked in the future
generate StillInCareCD4VL=1
replace StillInCareCD4VL=0 if CurrentDaysUntilNextCD4==.
replace StillInCareCD4VL=0 if CurrentDaysUntilNextVL==.

generate VirologicallySuppressed=0
//The next line states that you are VL suppressed on a date if your last VL was under 400 (some pts had labs under the old system)
//, and it was either measured in the last 90 days or it will be measured again in the next 90 days and will be suppressed then as well.
replace VirologicallySuppressed=1 if ((LVCFViralLoad<=400))&( CurrentDaysSinceLastViralLoad<=90 | ( CurrentDaysUntilNextVL<=90 & NextViralLoad<=400 ) )


save "Data Analytic file $DateOfAnalysis.dta", replace
