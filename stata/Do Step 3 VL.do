//Flash single vs double data set
//This creates a VL file
//12-16-2014 edition
//This file inputs the VL data from comma-separated variable files, and creates a wide format Stata data set with viral loads and dates obtained.

//We input the VL data from the CSV, drop unnecessary variables, and rename the output as "VLResultNumeric"
clear
insheet using "Excel VL_DeID.csv", comma
drop testtype result
rename resultnumeric VLResultNumeric

//We convert the date variable to Stata format
generate VLDate=date( testdate , "MDY")
format VLDate %tdnn/dd/YY
drop testdate

//We now reshape wide for the purposes of merging after saving the width of the file in the Global $MaxNumberVLMeasurements
sort studyid VLDate
by studyid: generate N=_n
quietly summarize N
global MaxNumberVLMeasurements `r(max)'
reshape wide VLResultNumeric VLDate , i(studyid) j(N)
save "Data VL $DateOfAnalysis.dta", replace
clear
