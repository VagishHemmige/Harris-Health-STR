//Flash-Zerai analysis
//CD4 file
//This file inputs the CD4 data from comma-separated variable files, and creates a wide format Stata data set with CD4s and dates obtained.
//12-16-2014 edition

//We input the CD4 data from the CSV and we drop the meaningless testtype variable:
clear
insheet using "Excel CD_4_DeID.csv", comma
drop testtype
rename resultnumeric CD4Result

//We convert the string dates to Stata format:
generate CD4Date=date( testdate , "MDY")
drop testdate
format CD4Date %tdnn/dd/YY

//Now, we create a wide format data set, saving the width in the Global $MaxNumberCD4Measurements
sort studyid CD4Date
by studyid: generate N=_n
quietly summarize N
global MaxNumberCD4Measurements `r(max)'
reshape wide CD4Result CD4Date, i(studyid) j(N)
save "Data CD4 $DateOfAnalysis.dta", replace
clear
