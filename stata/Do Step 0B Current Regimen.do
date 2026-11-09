//Flash-Zerai analysis
//Step 0 file
//This file assigns an initial regimen and current regimen to every patient
//11-1-2015 version

clear

//Input the antiretroviral dispensing file
insheet using "Excel Antiretrovirals_Taken_DeID.csv", comma

//Several medications are listed as "Experimental" or "other" in drug name
//We replace these with the actual drug name
replace drugname="Kaletra" if cdmdescription=="H-23052 KALETRA 200/50MG TAB"
replace drugname="Kaletra" if cdmdescription=="H-23052 LOPINAVIR/RI"
replace drugname="Epivir" if cdmdescription=="H-23052 LAMIVUDINE 1"
replace drugname="Epivir" if cdmdescription=="H-23052 LAMIVUDINE 300MG TAB"
replace drugname="Isentress" if cdmdescription=="HSC-070511 RALTEGRAV 400MG T"
replace drugname="Complera" if cdmdescription=="COMPLERA 200-25-300 TAB"

//Converts the string date to a Stata date and drops the variable with the string date
generate ARTDate=date( medtransdate , "MDY")
format ARTDate %tdnn/dd/YY
drop medtransdate

//Now, we generate a variable DispenseNumber that keeps a running total of how many unique dispense dates
//each patient has, after sorting and creating a variable NewDispense which labels the first dispense for every pt and unique date:
sort studyid ARTDate drugname
by studyid: generate N=_n
generate NewDispense=0
by studyid: replace NewDispense=1 if ((N>1)&( ARTDate[_n]>ARTDate[_n-1]))
replace NewDispense=1 if N==1
by studyid: generate DispenseNumber=sum(NewDispense)
drop NewDispense
drop N

//We create a variable BIDDrug which labels a drug being dispensed as BID.
generate BIDDrug=0
replace BIDDrug=1 if (cdmdescription=="KALETRA SOLN 400-100" |cdmdescription=="KALETRA      400-100"|cdmdescription=="ISENTRESS 400MG TAB" |cdmdescription=="INTELENCE 200MG TAB" |cdmdescription=="INTELENCE 100MG TAB" | cdmdescription=="HSC-090025 RALTEGRAV" |cdmdescription=="HSC-080661 RALTEGRAV" |cdmdescription=="HSC-080071 RALTEGRAV" | cdmdescription=="HSC-080071 RALTEGRAV"| cdmdescription=="HSC-070511 RALTEGRAV"| cdmdescription=="H-23052 LOPINAVIR/RI"| cdmdescription=="H-23052 KALETRA 200/5"| cdmdescription=="DARUNAVIR 600MG TAB"| cdmdescription=="DARUNAVIR 300MG"| cdmdescription=="COMBIVIR 300-150 TAB"|cdmdescription=="H-23052 KALETRA 200/50MG TAB"|cdmdescription=="HSC-070511 RALTEGRAV 400MG T"|cdmdescription=="HSC-070511 RALTEGRAV 400MG T"|cdmdescription=="HSC-080661 RALTEGRAV 400MG T"|cdmdescription=="KALETRA      400-100 LIQ"|cdmdescription=="KALETRA 200-50MG TAB"|cdmdescription=="KALETRA SOLN 400-100 LIQ"|cdmdescription=="HSC-080071 RALTEGRAV 400MG T" )
replace BIDDrug=1 if ( cdmdescription=="ZIDOVUDINE SYRUP 50MG/5ML SY" | cdmdescription=="ZIDOVUDINE 300MG TAB" | cdmdescription=="TRIZIVIR 300/150/300" |cdmdescription=="TRIZIVIR 300-300-150 TAB" | cdmdescription=="SELZENTRY 150MG TAB" |cdmdescription=="RITONAVIR-LOPINAVIR" |cdmdescription=="RETROVIR SYRUP 50MG/5ML SYR"|cdmdescription=="RETROVIR 50MG/5ML SYR" |cdmdescription=="RALTEGRAVIR 400MG" |cdmdescription=="PREZISTA 600MG TAB" | cdmdescription=="MARAVIROC 150 MG TAB" |cdmdescription=="LOPINAVIR/RITONAVIR" |cdmdescription=="LAMIVUDINE/ZIDOVUDIN"|cdmdescription=="LAMIVUDINE-ZIDOVUDIN TAB"   )
tab cdmdescription BIDDrug

//We now create a string variable CurrentRegimen which contains the current regimen on that date based on medications filled on that date
bysort studyid DispenseNumber ( drugname) : generate M=_n
quietly summarize M
global SizeOfLargestRegimen `r(max)' //Stores the maximum number of drugs any patient is taking simultaneously

//Now we reshape wide based on number of drugs dispensed on a date
reshape wide drugname cdmcode cdmdescription cdpdrugcode drugconstituents BIDDrug , i( studyid DispenseNumber ) j( M)

//The following loop creates the variable CurrentRegimen by adding together the various drugnames for any given date
generate CurrentRegimen=drugname1
forvalue i=2(1)$SizeOfLargestRegimen {
replace CurrentRegimen=CurrentRegimen+"/"+ drugname`i'
}
replace CurrentRegimen = reverse(substr(reverse(CurrentRegimen), indexnot(reverse(CurrentRegimen), "/"), .)) //Trims unnecessary /'s at end of line
//Now we reshape wide so that each row is a single drug dispensed on a single date
reshape long drugname cdmcode cdmdescription cdpdrugcode drugconstituents BIDDrug, i( studyid DispenseNumber ) j( M)
drop M
drop if drugname==""

//Obviously, the above code fails if a patient is only filling part of the regimen.
//Accordingly, we manually fix the errors that result:

//--- REMOVED FOR PRIVACY --------------------------------------------
// 576 manual per-patient correction(s) to CurrentRegimen were applied here, one per line, of the form
//   replace CurrentRegimen="<regimen>" if ((studyid==<id>) & (ARTDate==date("<m/d/y>", "MDY")))
// (396 limited to a dispensing date or date range; 180 applied to all of a patient's fills).
// 43 comment line(s) describing individual patients were also removed.
// Study IDs and dates are not published. See stata/README.md.
//--------------------------------------------------------------------

//Early after Complera came out, it is saved in the database as Truvada
//We need to replace this with the actual drug:
tab studyid if (drugname=="Truvada" && CurrentRegimen=="Complera")
// [1 note(s) about individual patients removed for privacy]
replace drugname="Complera" if (drugname=="Truvada" && CurrentRegimen=="Complera")

//We examine all of the final Regimens to make sure that they make sense
tab CurrentRegimen

//We look at which medications are dispensed with every regimen to make sure that the above regimens are correct:
bysort CurrentRegimen: tab drugname
sort studyid ARTDate drugname

tab studyid if CurrentRegimen=="Atripla" && drugname=="Sustiva"
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Atripla/Norvir/Reyataz/Truvada"
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Atripla/Prezista/Viread/Ziagen"
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Combivir/Norvir/Prezista" && drugname=="Reyataz"
tab studyid if CurrentRegimen=="Combivir/Norvir/Prezista" && drugname=="Truvada"
tab studyid if CurrentRegimen=="Combivir/Norvir/Reyataz" && drugname=="Epzicom"
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Complera" && drugname!="Complera"
tab studyid if CurrentRegimen=="Epivir"
tab studyid if CurrentRegimen=="Epivir/Kaletra" && drugname=="Epzicom"
tab studyid if CurrentRegimen=="Epivir/Norvir"
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Epzicom"
tab studyid if CurrentRegimen=="Epzicom/Norvir/Reyataz" && (drugname=="Combivir" | drugname=="Prezista" | drugname=="Sustiva")
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Epzicom/Norvir/Prezista" && (drugname=="Combivir" | drugname=="Reyataz" | drugname=="Sustiva")
tab studyid if CurrentRegimen=="Isentress"
tab studyid if CurrentRegimen=="Isentress/Kaletra/Viread" && (drugname=="Atripla")
tab studyid if CurrentRegimen=="Isentress/Norvir/Truvada"
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Isentress/Truvada" && (drugname=="Complera" )
tab studyid if CurrentRegimen=="Isentress/Truvada" && (drugname=="Epzicom" )
tab studyid if CurrentRegimen=="Isentress/Truvada" && (drugname=="Norvir" )
// [1 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Kaletra"
// [6 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Kaletra/Truvada" && (drugname=="Atripla" )
tab studyid if CurrentRegimen=="Kaletra/Truvada" && (drugname=="Isentress" )
tab studyid if CurrentRegimen=="Norvir/Prezista/Truvada" && (drugname=="Epivir" )
tab studyid if CurrentRegimen=="Norvir/Prezista/Truvada" && (drugname=="Isentress" )
tab studyid if CurrentRegimen=="Norvir/Prezista/Truvada" && (drugname=="Epzicom" )
tab studyid if CurrentRegimen=="Norvir/Prezista/Truvada" && (drugname=="Kaletra" )
tab studyid if CurrentRegimen=="Norvir/Reyataz/Truvada" && (drugname=="Atripla" )
tab studyid if CurrentRegimen=="Norvir/Reyataz/Truvada" && (drugname=="Prezista" )
tab studyid if CurrentRegimen=="Norvir/Reyataz/Viread/Ziagen" && (drugname=="Truvada" )
tab studyid if CurrentRegimen=="Reyataz"
//Only filled Reyataz; never filled another medication
tab studyid if CurrentRegimen=="Truvada"
// [8 note(s) about individual patients removed for privacy]
tab studyid if CurrentRegimen=="Ziagen"
// [1 note(s) about individual patients removed for privacy]


//We encode the CurrentRegimen variable to save space:
encode CurrentRegimen, generate(CurrRegimen)
drop CurrentRegimen
rename CurrRegimen CurrentRegimen

//We now create a file which contains one line for each new regimen and the start date.
//The maximum number of new regimens per subject is saved in the global $MaxNumberRegimens

bysort studyid (ARTDate): generate N=_n
generate NewRegimen=0
replace NewRegimen=1 if N==1
by studyid: replace NewRegimen=1 if ((N>1)&( CurrentRegimen[_n]~=CurrentRegimen[_n-1]))
by studyid: generate RegimenNumber=sum(NewRegimen)
quietly summarize RegimenNumber
global MaxNumberRegimens `r(max)'
display "Maximum number of regimens: " $MaxNumberRegimens

//Now we write code that labels whether dispenses or regimens are BID:
bysort studyid DispenseNumber: egen BIDDispense=max(BIDDrug) //Labels each dispense as being BID or not
bysort studyid RegimenNumber: egen BIDRegimen=max(BIDDrug) //Labels each new regimen as BID

//We identify regimens where the standard deviation of BID by dispense is greater than 0--i.e., the regimen changes from being BID to not BID:
by studyid RegimenNumber: egen BIDDispenseSD=sd(BIDDispense)
tab studyid if BIDDispenseSD>0
//keep if BIDDispenseSD>0
//drop if BIDDispenseSD==.
//We browse the data set looking at the above with code uncommented and find that the regimens typically change status from dispense to dispense
//because the BID drug is missed at a dispense.

//We then identify whether any specific drug varies from BID to not BID within a specific patient:
bysort studyid drugname: egen BIDDrugSD=sd(BIDDrug)
tab BIDDrugSD, missing
//keep if BIDDrugSD>0
//drop if BIDDrugSD==.
//We browse the data and there are only a handful of people who switch from BID to daily DRV; we need to figure out later what to do with them.

//We only keep the observations correlating to regimen changes and dump the unnecessary variables:
keep if NewRegimen
drop NewRegimen
drop N
rename ARTDate RegimenStartDate
keep studyid CurrentRegimen RegimenNumber BIDRegimen RegimenStartDate

//We reshape wide and then save:
reshape wide RegimenStartDate CurrentRegimen BIDRegimen, i(studyid) j(RegimenNumber)
save "Data CurrentRegimen $DateOfAnalysis.dta", replace
clear
