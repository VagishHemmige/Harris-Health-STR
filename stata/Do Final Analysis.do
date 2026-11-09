
use "Data Analytic file $DateOfAnalysis.dta", clear



generate VirologicallySuppressed2=0
//The next line states that you are VL suppressed on a date if your last VL was under 400 (some pts had labs under the old system)
//, and it was either measured in the last 90 days or it will be measured again in the next 90 days and will be suppressed then as well.
//The new variable chooses the marker for VL suppression by year




drop undetectable IntakeDate FirstUndetectDate
generate InitialRegimen=CurrentRegimen if CurrentRegimenNumber==1
drop if CurrentRegimenNumber==.
bysort studyid (CurrentDate): carryforward InitialRegimen, replace
generate FirstObservationOfSubject=(M==1)&(CurrentRegimenNumber==1)
generate InitialRegimenBID= CurrentBIDRegimen if CurrentRegimenNumber==1
by studyid: carryforward InitialRegimenBID, replace
tab InitialRegimenBID if FirstObservationOfSubject
drop if InitialRegimenBID
drop InitialRegimenBID
keep if ((InitialRegimen=="Atripla")|(InitialRegimen=="Norvir/Prezista/Truvada")|(InitialRegimen=="Norvir/Reyataz/Truvada"))
tab prevcareelsewhere if FirstObservationOfSubject
display 1158-1046
drop if prevcareelsewhere

tab InitialRegimen if (M==1)&(CurrentRegimenNumber==1)
generate InitialRegimenSTR= (InitialRegimen=="Stribild")|(InitialRegimen=="Atripla")|(InitialRegimen=="Complera")
tab InitialRegimenSTR if FirstObservationOfSubject
generate StillTakingInitialRegimen= (CurrentRegimenNumber==1)
generate DateofARTInitiation=CurrentDate if FirstObservationOfSubject
by studyid: carryforward DateofARTInitiation, replace
format DateofARTInitiation %tdnn/dd/YY
generate YearofARTInitiation=year( DateofARTInitiation)
generate DaysSinceARTInitiation= CurrentDate-DateofARTInitiation
generate WeeksSinceARTInitiation= DaysSinceARTInitiation/7

tab Insurance if FirstObs
tab Insurance if FirstObs, missing
tab Insurance InitialRegimenSTR if FirstObs, missing
tab Insurance InitialRegimenSTR if FirstObs, missing row
logit InitialRegimenSTR i.Insurance if FirstObs
logit InitialRegimenSTR i3.Insurance if FirstObs
drop if Insurance==.


replace VirologicallySuppressed2=1 if ((LVCFViralLoad<=400))&( CurrentDaysSinceLastViralLoad<=90 | ( CurrentDaysUntilNextVL<=90 & NextViralLoad<=400 ) )&(YearofARTInitiation==2008)
replace VirologicallySuppressed2=1 if ((LVCFViralLoad<=50))&( CurrentDaysSinceLastViralLoad<=90 | ( CurrentDaysUntilNextVL<=90 & NextViralLoad<=50 ) )&(YearofARTInitiation>2008)



tab InitialRegimenSTR if FirstObs

//Some quarter analysis
egen Quarter = cut( DaysSinceARTInitiation ), at(0,1,92,183,274,365) icodes label
bysort studyid Quarter (CurrentDate): egen ProportionDaysCoveredInQuarter=mean( DayIsCovered)
bysort studyid Quarter (CurrentDate): egen AchievedVLSuppressionQuarter=max(VirologicallySuppressed)
replace AchievedVLSuppressionQuarter=. if Quarter==.

//Changing regimen
by studyid: egen CurrentRegimenNumberSD=sd( CurrentRegimenNumber)
generate ChangesRegimen=(CurrentRegimenNumberSD~=0)
drop CurrentRegimenNumberSD

//We analyze how many individuals change their regimen:
tab InitialRegimenSTR ChangesRegimen if FirstObservationOfSubject, row column chi2

//We compare demographics of people who do and don't receive an STR
tab InitialRegimenSTR Gender if FirstObservationOfSubject, row column chi2
tab InitialRegimenSTR hepc if FirstObservationOfSubject, row column chi2
tab InitialRegimenSTR Ethnicity if FirstObservationOfSubject, row column chi2
tab InitialRegimenSTR RiskFactor if FirstObservationOfSubject, row column chi2
summarize age if (InitialRegimenSTR==0)&FirstObservationOfSubject, detail
summarize age if (InitialRegimenSTR==1)&FirstObservationOfSubject, detail
ttest age if FirstObservation, by(InitialRegimenSTR)
summarize LVCFViralLoad if (InitialRegimenSTR==0)&FirstObservationOfSubject, detail
summarize LVCFViralLoad if (InitialRegimenSTR==1)&FirstObservationOfSubject, detail
ttest LVCFViralLoad if FirstObservation, by(InitialRegimenSTR)
ranksum LVCFViralLoad if FirstObservation, by(InitialRegimenSTR)
summarize LVCFCD4 if (InitialRegimenSTR==0)&FirstObservationOfSubject, detail
summarize LVCFCD4 if (InitialRegimenSTR==1)&FirstObservationOfSubject, detail
ttest LVCFCD4 if FirstObservation, by(InitialRegimenSTR)
ranksum LVCFCD4 if FirstObservation, by(InitialRegimenSTR)
tab Insurance InitialRegimenSTR if FirstObs, row chi2

//We create a variable which categorizes age:
egen AgeCategorical = cut( age), at(0, 25,35,45,55,65, 100) icodes label
tab InitialRegimenSTR AgeCategorical if FirstObservationOfSubject, row column chi2

//We create a variable which categorizes initial viral load
egen InitialViralLoadCategorical = cut( LVCFViralLoad ) if FirstObservationOfSubject, at(0, 401,1000,10000,100000,1000000,10000001) icodes label
tab InitialRegimenSTR InitialViralLoadCategorical if FirstObservationOfSubject, row column chi2
bysort studyid (CurrentDate): carryforward InitialViralLoadCategorical, replace

//We create a variable which categorizes initial CD4
egen InitialCD4Categorical = cut( LVCFCD4 ) if FirstObservationOfSubject, at(0, 50,100,200,500,1000000) icodes label
tab InitialRegimenSTR InitialCD4Categorical if FirstObservationOfSubject, row column chi2
bysort studyid (CurrentDate): carryforward InitialCD4Categorical, replace

//We see if patients who switch to new regimens are virologically suppressed or not:
tab VirologicallySuppressed if (CurrentRegimenNumber==2)&(M==1)
tab VirologicallySuppressed if (CurrentRegimenNumber==2)&(M==1)&(InitialRegimenSTR==1)
tab VirologicallySuppressed if (CurrentRegimenNumber==2)&(M==1)&(InitialRegimenSTR==0)
logistic VirologicallySuppressed InitialRegimenSTR if (CurrentRegimenNumber==2)&(M==1)

//We calculate propensity score and inverse probability weights (IPW)
logistic InitialRegimenSTR hepc Gender Black Hispanic IDU MSM i.AgeCategorical i.InitialViralLoadCategorical i.InitialCD4Categorical i3.Insurance if FirstObservationOfSubject
predict PropensityScore, p
generate IPW=(InitialRegimenSTR/PropensityScore)+(1-InitialRegimenSTR)/(1-PropensityScore)

//We compare demographics of people who do and don't receive an STR, now using the IPW weighting scheme
tab InitialRegimenSTR Gender if FirstObservationOfSubject [aw=IPW], row column
tab InitialRegimenSTR hepc if FirstObservationOfSubject [aw=IPW], row column
tab InitialRegimenSTR Ethnicity if FirstObservationOfSubject [aw=IPW], row column
tab InitialRegimenSTR RiskFactor if FirstObservationOfSubject [aw=IPW], row column
summarize age if (InitialRegimenSTR==0)&FirstObservationOfSubject [aw=IPW], detail
summarize age if (InitialRegimenSTR==1)&FirstObservationOfSubject [aw=IPW], detail
summarize LVCFViralLoad if (InitialRegimenSTR==0)&FirstObservationOfSubject [aw=IPW], detail
summarize LVCFViralLoad if (InitialRegimenSTR==1)&FirstObservationOfSubject [aw=IPW], detail
summarize LVCFCD4 if (InitialRegimenSTR==0)&FirstObservationOfSubject [aw=IPW], detail
summarize LVCFCD4 if (InitialRegimenSTR==1)&FirstObservationOfSubject [aw=IPW], detail
tab InitialRegimenSTR AgeCategorical if FirstObservationOfSubject [aw=IPW], row column
tab InitialRegimenSTR InitialViralLoadCategorical if FirstObservationOfSubject [aw=IPW], row column
tab InitialRegimenSTR InitialCD4Categorical if FirstObservationOfSubject [aw=IPW], row column
tab InitialRegimenSTR Insurance if FirstObservationOfSubject [aw=IPW], row column



//We calculate still in care first year based on HRSA definitions
generate IsViralLoadMeasurementDate= CurrentVL<.
replace IsViralLoadMeasurementDate=. if IsViralLoadMeasurementDate==0
replace IsViralLoadMeasurementDate=. if Quarter==.
by studyid: egen TotalNumberVLMeasured=sum( IsViralLoadMeasurementDate)
generate ViralLoadMeasurementDate= IsViralLoadMeasurementDate*CurrentDate
replace ViralLoadMeasurementDate=. if Quarter==.
by studyid: egen FirstVLMeasurementDate=min( ViralLoadMeasurementDate)
by studyid: egen LastVLMeasurementDate=max( ViralLoadMeasurementDate)
generate GapBetweenFirstLastVL= LastVLMeasurementDate- FirstVLMeasurementDate
generate RetainedInCareFirstYear=0
replace RetainedInCareFirstYear=1 if (( TotalNumberVLMeasured>=2)&( GapBetweenFirstLastVL>90 ))
drop IsViralLoadMeasurementDate TotalNumberVLMeasured ViralLoadMeasurementDate FirstVLMeasurementDate LastVLMeasurementDate GapBetweenFirstLastVL

// [A line that deliberately stopped the do-file here was removed.]
///Data analysis
tab RetainedInCareFirstYear InitialRegimenSTR if FirstObservationOfSubject, row column chi2
display "logistic RetainedInCareFirstYear InitialRegimenSTR if FirstObservationOfSubject"
logistic RetainedInCareFirstYear InitialRegimenSTR if FirstObservationOfSubject
display "logistic RetainedInCareFirstYear InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]"
logistic RetainedInCareFirstYear InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]

//We now see if rates of ever achieving VL suppression in the first year differ between the two regimens:
by studyid: egen AchievedVLSuppressionYear=max(AchievedVLSuppressionQuarter)
tab AchievedVLSuppressionYear InitialRegimenSTR if FirstObservationOfSubject, row column chi2
display "logistic AchievedVLSuppressionYear InitialRegimenSTR if FirstObservationOfSubject"
logistic AchievedVLSuppressionYear InitialRegimenSTR if FirstObservationOfSubject
display "logistic AchievedVLSuppressionYear InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]"
logistic AchievedVLSuppressionYear InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]

generate VirologicallySuppInitReg= StillTakingInitialRegimen* VirologicallySuppressed
by studyid: egen AchievedVLSuppInitReg=max(VirologicallySuppInitReg)
tab AchievedVLSuppInitReg InitialRegimenSTR if FirstObservationOfSubject, chi row column
logistic AchievedVLSuppInitReg InitialRegimenSTR if FirstObservationOfSubject
logistic AchievedVLSuppInitReg InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]

by studyid: egen PropDC=mean(DayIsCovered)
generate PropDCOver80=.
replace PropDCOver80=1 if (PropDC>=0.8)&( PropDC~=. )
replace PropDCOver80=0 if (PropDC<0.8)
tab PropDCOver80 InitialRegimenSTR if FirstObservationOfSubject, row column chi2
logistic PropDCOver80 InitialRegimenSTR if FirstObservationOfSubject
logistic PropDCOver80 InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]
generate VirologicallySuppressed2=0
replace VirologicallySuppressed2=1 if ((LVCFViralLoad<=400))&( CurrentDaysSinceLastViralLoad<=90 | ( CurrentDaysUntilNextVL<=90 & NextViralLoad<=400 ) )&(YearofARTInitiation==2008)
replace VirologicallySuppressed2=1 if ((LVCFViralLoad<=50))&( CurrentDaysSinceLastViralLoad<=90 | ( CurrentDaysUntilNextVL<=90 & NextViralLoad<=50 ) )&(YearofARTInitiation>2008)
by studyid: egen AchievedVLSupp2=max(VirologicallySuppressed2)
logistic InitialRegimenSTR i.YearofARTInitiation
tab InitialRegimenSTR YearofARTInitiation
logistic InitialRegimenSTR i.YearofARTInitiation if FirstObs
tab InitialRegimenSTR YearofARTInitiation if FirstObs
tab InitialRegimenSTR YearofARTInitiation if FirstObs, column
tab InitialRegimenSTR AchievedVLSupp2 if FirstObservationOfSubject, row column chi2
tab InitialRegimenSTR AchievedVLSupp2 if (FirstObservationOfSubject)&( YearofARTInitiation==2008) , row column chi2
tab InitialRegimenSTR AchievedVLSupp2 if (FirstObservationOfSubject)&( YearofARTInitiation==2009) , row column chi2
tab InitialRegimenSTR AchievedVLSupp2 if (FirstObservationOfSubject)&( YearofARTInitiation==2010) , row column chi2
tab InitialRegimenSTR AchievedVLSupp2 if (FirstObservationOfSubject)&( YearofARTInitiation==2011) , row column chi2
tab InitialRegimenSTR AchievedVLSupp2 if (FirstObservationOfSubject)&( YearofARTInitiation==2012) , row column chi2
generate HadPsychDate=(PsychDate1~=.)
tab InitialRegimenSTR HadPsychDate if FirstObs, row column chi2
logistic InitialRegimenSTR hepc Gender Black Hispanic IDU MSM i.AgeCategorical i.InitialViralLoadCategorical i.InitialCD4Categorical i3.Insurance HadPsychDate if FirstObservationOfSubject
predict PropensityScore2, p
generate IPW2=(InitialRegimenSTR/PropensityScore2)+(1-InitialRegimenSTR)/(1-PropensityScore2)
logistic RetainedInCareFirstYear InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]
logistic AchievedVLSuppressionYear InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]
generate DayCoveredInitRegimen= DayIsCovered* StillTakingInitialRegimen
by studyid: egen PropDCInitRegimen=mean(DayCoveredInitRegimen)
generate PropDCOver80InitReg=.
replace PropDCOver80InitReg=1 if (PropDCInitRegimen>=0.8)&( PropDCInitRegimen~=. )
replace PropDCOver80InitReg=0 if (PropDCInitRegimen<0.8)
tab PropDCOver80InitReg InitialRegimenSTR if FirstObservationOfSubject, row column chi2
logistic PropDCOver80InitReg InitialRegimenSTR if FirstObservationOfSubject
logistic PropDCOver80InitReg InitialRegimenSTR if FirstObservationOfSubject [pw=IPW]
generate CurrentDrugDispenseDate= (CurrentDrug1CurrentDispense==30)|( CurrentDrug2CurrentDispense==30)| (CurrentDrug3CurrentDispense==30)| (CurrentDrug4CurrentDispense)|( CurrentDrug5CurrentDispense==30)|( CurrentDrug6CurrentDispense==30)
tab CurrentDrugDispenseDate
generate DaysSinceLastDispense=.
replace DaysSinceLastDispense=0 if CurrentDrugDispenseDate
by studyid: replace DaysSinceLastDispense =1+ DaysSinceLastDispense[_n-1] if DaysSinceLastDispense==.
generate NegCurrentDate=-CurrentDate
sort studyid NegCurrentDate
generate DaysUntilNextDispense=.
replace DaysUntilNextDispense=0 if CurrentDrugDispenseDate
by studyid: replace DaysUntilNextDispense =1+ DaysUntilNextDispense[_n-1] if DaysUntilNextDispense==.
drop NegCurrentDate
sort studyid CurrentDate
generate GapBetweenFills= DaysSinceLastDispense+ DaysUntilNextDispense
tab CurrentVL if DaysSinceLastDispense>90
tab studyid if (CurrentVL<=400)&(DaysSinceLastDispense>=90)
generate VLSuppressedNoFill=(CurrentVL<=400)&(DaysSinceLastDispense>=90)
tab VLSuppressedNoFill, nomissing
by studyid: egen SwitchesPharmacy=max( VLSuppressedNoFill)
tab SwitchesPharmacy if FirstObservationOfSubject
tab SwitchesPharmacy InitialRegimenSTR if FirstObservationOfSubject, row column chi2
