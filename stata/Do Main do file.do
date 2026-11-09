//Flash single vs double data set
//11-1-2015 edition

//The following code sets up the defaults for the file
clear
set more off
set scheme lean1
global DateOfAnalysis 12-20-2017
cd "<your analysis folder>"   // local path removed
capture log close

//First, we set up the analytic file in a series of steps, tracking the output with the "Log Setup" file for later review:
log using "Log Setup.log", replace
//do "Do Step 0A Initial Regimen.do" //This step doesn't really do anything necessary as the subsequent step 0B has ALL regimens, not just initial.
do "Do Step 0B Current Regimen.do"
do "Do Step 1A Pharmacy Part 1.do"
//do "Do Step 1B Pharmacy Part 2.do" //This step is unnecessary as Step0B already flags all of the regimen changes
do "Do Step 2 CD4.do"
do "Do Step 3 VL.do"
do "Do Step 4 Demographic.do"
do "Do Step 4B Insurance.do"
do "Do Step 4C Psych.do"
do "Do Step 5 Merge and Expand.do"
do "Do Step 6 Tokenize Pharmacy.do"
do "Do Step 7 Merge Pharmacy.do"
do "Do Step 8 Data Preparation.do"
log close

// [A line that deliberately stopped the do-file here was removed.]

//Now, we customize the analysis specifically for the STR vs multiple once daily tabs study:
log using "Log Analysis 1.log", replace
do "Do Step 9 Data Analysis 1.do"
log close

log using "Log Analysis 2.log", replace
do "Do Step 10 Data Analysis 2.do"
log close

//This next step exports the numerical results of the prior steps into Excel
do "Do Step 11 Export Excel tables.do"

//And now we implement time to event analysis:
log using "Log Survival analysis.log", replace
do "Do Step 12 Survival analysis.do"
log close
