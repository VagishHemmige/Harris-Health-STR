//Creates pharmacy data from initial file

//Inputs the pharmacy file
clear
insheet using "Excel Antiretrovirals_Taken_DeID.csv", comma

//Changes the patients for whom drugname is "Experimental" or "Other"
replace drugname="Kaletra" if cdmdescription=="H-23052 KALETRA 200/50MG TAB"
replace drugname="Kaletra" if cdmdescription=="H-23052 LOPINAVIR/RI"
replace drugname="Epivir" if cdmdescription=="H-23052 LAMIVUDINE 1"
replace drugname="Epivir" if cdmdescription=="H-23052 LAMIVUDINE 300MG TAB"
replace drugname="Isentress" if cdmdescription=="HSC-070511 RALTEGRAV 400MG T"
replace drugname="Complera" if cdmdescription=="COMPLERA 200-25-300 TAB"

//Convert Date from string to Stata format and sorts
generate ARTDate=date( medtransdate , "MDY")
format ARTDate %tdnn/dd/YY
drop medtransdate
sort studyid ARTDate

//--- REMOVED FOR PRIVACY --------------------------------------------
// 5 manual per-patient correction(s) to drugname were applied here, one per line, of the form
//   replace drugname="<regimen>" if ((studyid==<id>) & (ARTDate==date("<m/d/y>", "MDY")))
// (3 limited to a dispensing date or date range; 2 applied to all of a patient's fills).
// 1 comment line(s) describing individual patients were also removed.
// Study IDs and dates are not published. See stata/README.md.
//--------------------------------------------------------------------

//we label regimens which are BID and which are single pill
tab cdmdescription
generate BIDDrug=0
replace BIDDrug=1 if ( cdmdescription=="ZIDOVUDINE SYRUP 50MG/5ML SY" | cdmdescription=="ZIDOVUDINE 300MG TAB" | cdmdescription=="TRIZIVIR 300/150/300" |cdmdescription=="TRIZIVIR 300-300-150 TAB" | cdmdescription=="SELZENTRY 150MG TAB" |cdmdescription=="RITONAVIR-LOPINAVIR" |cdmdescription=="RETROVIR SYRUP 50MG/5ML SYR"|cdmdescription=="RETROVIR 50MG/5ML SYR" |cdmdescription=="RALTEGRAVIR 400MG" |cdmdescription=="PREZISTA 600MG TAB" | cdmdescription=="MARAVIROC 150 MG TAB" |cdmdescription=="LOPINAVIR/RITONAVIR" |cdmdescription=="LAMIVUDINE/ZIDOVUDIN"|cdmdescription=="LAMIVUDINE-ZIDOVUDIN TAB"   )
replace BIDDrug=1 if (cdmdescription=="KALETRA SOLN 400-100" |cdmdescription=="KALETRA      400-100"|cdmdescription=="ISENTRESS 400MG TAB" |cdmdescription=="INTELENCE 200MG TAB" |cdmdescription=="INTELENCE 100MG TAB" | cdmdescription=="HSC-090025 RALTEGRAV" |cdmdescription=="HSC-080661 RALTEGRAV" |cdmdescription=="HSC-080071 RALTEGRAV" | cdmdescription=="HSC-080071 RALTEGRAV"| cdmdescription=="HSC-070511 RALTEGRAV"| cdmdescription=="H-23052 LOPINAVIR/RI"| cdmdescription=="H-23052 KALETRA 200/5"| cdmdescription=="DARUNAVIR 600MG TAB"| cdmdescription=="DARUNAVIR 300MG"| cdmdescription=="COMBIVIR 300-150 TAB"|cdmdescription=="H-23052 KALETRA 200/50MG TAB"|cdmdescription=="HSC-070511 RALTEGRAV 400MG T"|cdmdescription=="HSC-070511 RALTEGRAV 400MG T"|cdmdescription=="HSC-080661 RALTEGRAV 400MG T"|cdmdescription=="KALETRA      400-100 LIQ"|cdmdescription=="KALETRA 200-50MG TAB"|cdmdescription=="KALETRA SOLN 400-100 LIQ"|cdmdescription=="HSC-080071 RALTEGRAV 400MG T" )
tab cdmdescription BIDDrug
generate SinglePillRegimen=0
replace SinglePillRegimen=1 if (cdmdescription=="STRIBILD  TAB"|cdmdescription=="ATRIPLA TAB"|cdmdescription=="ATRIPLA 200-300-600M"| cdmdescription=="COMPLERA 200-25-300 TAB")
tab cdmdescription SinglePillRegimen
sort studyid
by studyid: generate N=_n

//We encode variables to save space:
encode cdmdescription, generate(CDMDescription)
drop cdmdescription
encode drugname, generate(DrugName)
drop drugname
encode drugconstituents, generate(DrugConstituents)
drop drugconstituents

//We create a global $MaxNumDrugs which saves the maximum number of drugs dispensed for a single subject (~147):
quietly summarize N
global MaxNumDrugs `r(max)'
display "Maximum number of drugs is: " $MaxNumDrugs

//We reshape the fill data wide (so each subject has one line) and save:
reshape wide cdmcode CDMDescription cdpdrugcode DrugName DrugConstituents ARTDate BIDDrug SinglePillRegimen, i( studyid) j(N)
save "Data Pharmacy $DateOfAnalysis.dta", replace
clear
