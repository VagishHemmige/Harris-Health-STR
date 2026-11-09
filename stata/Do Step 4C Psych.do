//Flash single vs double data set
//This creates a psych file
//12-20-2017 edition
//This file inputs the data of any psych visits

clear
insheet using "PsychVisits_DeID.csv", comma

//We convert the date variable to Stata format
generate PsychDate=date( psychvisitdate , "MDY")
format PsychDate %tdnn/dd/YY
drop psychvisitdate

sort studyid PsychDate
by studyid: generate N=_n
quietly summarize N
global MaxNumberPsychMeasurements `r(max)'
reshape wide PsychDate , i(studyid) j(N)

save "Data Psych visits $DateOfAnalysis.dta", replace

