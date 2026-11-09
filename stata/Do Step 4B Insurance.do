//Flash single vs double data set
//This creates an insurance file
//12-20-2017 edition
//This file inputs the insurance and prior care data

clear
insheet using "ElementsAtIntake_DeID.csv", comma
encode insurancestatus, generate(Insurance)
drop insurancestatus
save "Data Insurance $DateOfAnalysis.dta", replace
clear
