//Flash single vs double data set
//Creates a Stata file with demographic characteristics
//12-16-2014 edition

clear

//First, we input the demographic information
insheet using "Excel Cohort_DeID.csv", comma

//We convert the date variables "IntakeDate" and "first_undetect_date" to Stata format
generate IntakeDate=date( intake_date , "MDY")
format IntakeDate %tdnn/dd/YY
drop intake_date
generate FirstUndetectDate=date( first_undetect_date, "MDY")
drop first_undetect_date
format FirstUndetectDate %tdnn/dd/YY

//We examine all of the predictors and clean up the variables a little bit.
//We also define the variables Black, Hispanic, IDU, and MSM based on the underlying variables
summarize age, detail
tab age, missing
tab gender, missing
replace gender="F" if gender=="f"
replace gender="M" if gender=="m"
tab ethnicity, missing
replace ethnicity="B" if ethnicity=="b"
replace ethnicity="H" if ethnicity=="h"
generate Black=(ethnicity=="B")
generate Hispanic=(ethnicity=="H")
tab primaryriskfactor, missing
generate IDU=( primaryriskfactor=="IDU" | primaryriskfactor=="MSM&IDU")
generate MSM=( primaryriskfactor=="MSM" |primaryriskfactor=="MSM&IDU" )

//Now, we encode Gender, Ethnicity, and RiskFactor variables as numbers, instead of strings, to save space:
encode gender, generate(Gender)
drop gender
encode ethnicity, generate(Ethnicity)
drop ethnicity
encode primaryriskfactor, generate(RiskFactor)
drop primaryriskfactor

//We save the dataset
save "Data Demographic $DateOfAnalysis.dta", replace
clear
