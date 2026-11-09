//Flash-Zerai analysis
//This file creates the long version data set from demographic variables, CD4, and VL
//The data set created is "Data ExpandedCD4VLDemo $DateOfAnalysis.dta"
//12-16-2014 edition

//First, we open the data set with the demographic variables
use "Data Demographic $DateOfAnalysis.dta", clear

//Now, we add the CD4 variables, listing the observations who fail the merge (for whom there are no CD4 observations):
merge 1:1 studyid using "Data CD4 $DateOfAnalysis.dta"
tab studyid if _merge<3
drop _merge

//Now, we add the VL variables, listing the observations who fail the merge (for whom there are no VL observations):
merge 1:1 studyid using "Data VL $DateOfAnalysis.dta"
tab studyid if _merge<3
drop _merge

//Merge Insurance Data
merge 1:1 studyid using "Data Insurance $DateOfAnalysis.dta"
tab studyid if _merge<3
drop _merge

//Merge Psych visit data
merge 1:1 studyid using "Data Psych Visits $DateOfAnalysis.dta"
drop _merge

//Now we assign each subject 2192 observations and assign a date to each line, creating a long format data set
//"studyid" is the subject identifier and "CurrentDate" is the date of each observation
sort studyid
expand 2192
sort studyid
by studyid: generate N=_n
generate CurrentDate=N+17531
drop N
format CurrentDate %tdnn/dd/YY

//The following loop assigns the value of CD4 measured on a date to the variable "CurrentCD4" if it was actually measured on that specific date
//It then deletes the now superfluous CD4 variables, keeping only the CurrentCD4 variable
generate CurrentCD4=.
quietly forvalues counter=1(1)$MaxNumberCD4Measurements {
replace CurrentCD4=CD4Result`counter' if CurrentDate==CD4Date`counter'
}
drop CD4*

//The following loop assigns the value of VL measured on a date to the variable "CurrentVL" if it was actually measured on that specific date
//It then deletes the now superfluous VL variables, keeping only the CurrentVL variable
generate CurrentVL=.
quietly forvalues counter=1(1)$MaxNumberVLMeasurements {
replace CurrentVL=VLResultNumeric`counter' if CurrentDate==VLDate`counter'
}
drop VL*

//We create a variable which keeps track of the number of days since the last CD4 was measured for each date for each individual
generate CurrentDaysSinceLastCD4=.
replace CurrentDaysSinceLastCD4=0 if CurrentCD4~=.
by studyid: replace CurrentDaysSinceLastCD4=1+CurrentDaysSinceLastCD4[_n-1] if CurrentDaysSinceLastCD4==.

//We create a variable which keeps track of the number of days since the last VL was measured for each date for each individual
generate CurrentDaysSinceLastViralLoad=.
replace CurrentDaysSinceLastViralLoad=0 if CurrentVL~=.
by studyid: replace CurrentDaysSinceLastViralLoad=1+CurrentDaysSinceLastViralLoad[_n-1] if CurrentDaysSinceLastViralLoad==.

//We create variables which extrapolate Last Value Carried Forward values of CD4 and VL:
generate LVCFCD4=CurrentCD4
generate LVCFViralLoad=CurrentVL
by studyid: replace LVCFCD4=LVCFCD4[_n-1] if LVCFCD4==.
by studyid: replace LVCFViralLoad=LVCFViralLoad[_n-1] if LVCFViralLoad==.

//The following code creates variables which calculate the number of days until the next CD4 and VL are measured
//Obviously, the sum of this and the days since last CD4 equal the size of the gap between measurements:
generate NegCurrentDate=-CurrentDate
sort studyid NegCurrentDate
generate CurrentDaysUntilNextCD4=.
replace CurrentDaysUntilNextCD4=0 if CurrentCD4~=.
by studyid: replace CurrentDaysUntilNextCD4=1+CurrentDaysUntilNextCD4[_n-1] if CurrentDaysUntilNextCD4==.
generate CurrentDaysUntilNextVL=.
replace CurrentDaysUntilNextVL=0 if CurrentVL~=.
by studyid: replace CurrentDaysUntilNextVL=1+CurrentDaysUntilNextVL[_n-1] if CurrentDaysUntilNextVL==.
generate NextCD4=CurrentCD4
generate NextViralLoad=CurrentVL
by studyid: replace NextCD4=NextCD4[_n-1] if NextCD4==.
by studyid: replace NextViralLoad=NextViralLoad[_n-1] if NextViralLoad==.
generate LengthofCD4Gap=CurrentDaysUntilNextCD4+CurrentDaysSinceLastCD4
generate LengthofVLGap=CurrentDaysUntilNextVL+CurrentDaysSinceLastViralLoad

//We sort the dataset, drop unnecessary variables, and save it 
sort studyid CurrentDate
drop NegCurrentDate
save "Data ExpandedCD4VLDemo $DateOfAnalysis.dta", replace
