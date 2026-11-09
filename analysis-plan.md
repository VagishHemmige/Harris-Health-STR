# Analysis plan: Single-tablet vs multi-tablet first-line ART and retention and viral suppression

Status: retrospective. Reconstructed in November 2026 from the published paper [@hemmige2018str] and the analysis code (`stata/Do Final Analysis.do` and the data-build steps it relies on), for teaching. It records the analysis as it was done; no further analysis is planned.

## Scope and reporting framework

This document is the authoritative specification of the study's scientific objectives, population, definitions, estimands and statistical methods. `ARCHITECTURE.md` documents the implementation, `AGENTS.md` the working conventions, and GitHub Issues any open questions. Neither file supersedes this plan.

Where the code does something the paper's methods do not state, this plan describes what the code does and says so, marked **Differs from paper**.

Reporting followed STROBE [@vonelm2007strobe]; RECORD [@benchimol2015record] applies to studies of routinely collected data like this one. The reporting map below links checklist items to sections of this plan.

## 1. Objective

To compare, among treatment-naive patients starting antiretroviral therapy (ART), a single-tablet regimen (STR) with a once-daily multi-tablet regimen (MTR) on:

- **Primary:** retention in care and viral suppression in the first year.
- **Secondary:** viral suppression while on the initial regimen; adherence measured as proportion of days covered (PDC).

Hypothesis stated in advance: STR is associated with better retention and suppression.

## 2. Design

Retrospective cohort study using routinely collected clinic pharmacy and laboratory data. The comparison is observational; confounding by measured characteristics is addressed with inverse probability of treatment weighting (IPTW), targeting the average treatment effect in the cohort. Target-trial emulation was not used.

## 3. Data source

Thomas Street Health Center, Harris Health System, Houston, Texas. De-identified extracts, prepared for the study, of:

- Antiretroviral dispensing from the clinic pharmacy (drug, product description, date).
- CD4 counts and HIV-1 viral loads (date, numeric result).
- Demographics and HIV transmission risk at intake.
- Insurance status and prior HIV care elsewhere at intake.
- Psychiatry clinic visit dates.

Observation window: 1 January 2008 to 31 December 2013. The data are not public and are not in this repository.

## 4. Study population

Source population: patients with antiretrovirals dispensed by the clinic pharmacy during the window.

Exclusions, in order (each a flowchart step):

1. Initial regimen in the window is taken twice daily (any twice-daily product), or the first regimen started before the window.
2. Initial regimen is not one of: Atripla; Norvir/Prezista/Truvada; Norvir/Reyataz/Truvada.
3. Recorded as having had HIV care elsewhere, or that field missing. **Differs from paper:** not stated in the paper's methods.
4. Insurance status missing. **Differs from paper:** not stated in the paper's methods.

Index event (time zero): the first day of the first regimen (first fill).

## 5. Exposure and time zero

**Regimen.** On each fill date, the drugs dispensed are joined, in alphabetical order, into a regimen name. The original analyst manually corrected the regimen on specific fill dates where only part of a regimen was filled (576 corrections in the final code; not published). A Truvada fill on a date whose regimen is Complera is recoded as Complera. A new regimen starts on any fill date whose regimen name differs from the previous fill date's. A regimen is twice daily if any fill within it is a twice-daily product (list in `R/setup.R`).

**Exposure.** STR: initial regimen Atripla (efavirenz/tenofovir/emtricitabine). MTR: initial regimen Norvir/Prezista/Truvada or Norvir/Reyataz/Truvada (ritonavir-boosted darunavir or atazanavir with tenofovir/emtricitabine). Intention to treat: classified by initial regimen regardless of later switches.

**Covariates**, measured at time zero:

- Age (groups: <25, 25-34, 35-44, 45-54, 55-64, 65+), sex, Black race, Hispanic ethnicity, injection drug use, men who have sex with men, hepatitis C, insurance (the third insurance category in the extract; described in the paper as insured vs uninsured).
- Baseline viral load: last value on or before time zero (groups: 0-400, 401-999, 1,000-9,999, 10,000-99,999, 100,000-999,999, 1,000,000+ copies/mL).
- Baseline CD4: last value on or before time zero (groups: <50, 50-99, 100-199, 200-499, 500+ cells/µL).
- Any psychiatry visit on file (sensitivity analysis only).

## 6. Comparator or matching

No matching. Comparison by IPTW: weights 1/p for STR patients and 1/(1-p) for MTR patients, where p is the propensity score (§8).

## 7. Outcomes

Daily measures, on a grid of one row per patient per day:

- **Pills on hand**, per drug: every fill is 30 pills; +30 on a fill day, -1 per day, never below zero; a fill when none are left gives 30; pills of the same drug carry into a new regimen.
- **Day covered:** every drug in the current regimen on hand.
- **Virologically suppressed on a day:** last viral load ≤400 copies/mL and either measured within the previous 90 days, or the next viral load is within 90 days and also ≤400. **Differs from paper:** the paper says <400.

Patient outcomes:

- **Retention in care, year one:** at least two viral loads in days 0-364 after time zero, more than 90 days apart (HRSA-style definition using viral load tests).
- **Viral suppression, year one:** suppressed on at least one day in days 0-364.
- **Viral suppression on the initial regimen:** suppressed on at least one day while on the initial regimen. **Differs from paper:** uses all follow-up to 31 December 2013, not only year one.
- **Adherence:** PDC ≥ 0.80, with PDC the proportion of days covered. **Differs from paper:** averaged over all follow-up to 31 December 2013, not only year one.
- **Adherence on the initial regimen:** proportion of days that are both covered and on the initial regimen ≥ 0.80, over all follow-up.
- **Regimen change:** any change of regimen during follow-up (descriptive).

## 8. Statistical analysis

- **Descriptive:** baseline characteristics by group; Pearson chi-squared for categorical variables, t-test (equal variances) and Wilcoxon rank-sum for age, baseline viral load and CD4.
- **Propensity score:** logistic regression of STR on hepatitis C, sex, Black race, Hispanic ethnicity, injection drug use, MSM, age group, baseline viral load group, baseline CD4 group and insurance. Patients missing a covariate receive no weight and are excluded from weighted analyses.
- **Balance:** weighted proportions and means by group.
- **Outcome models:** for each outcome, logistic regression on STR, unadjusted and IPTW-weighted with robust standard errors. Odds ratios with Wald 95% confidence intervals.
- **Missing data:** complete cases for each model.
- **Multiplicity:** no adjustment.
- **Software:** Stata 12 (original); R (this teaching translation).

## 9. Sensitivity analyses

1. **Assay threshold:** suppression defined with ≤50 copies/mL for patients starting ART after 2008 (≤400 for 2008), tabulated by year of ART start. Tests whether the 400 cut-off, set by the 2008 assay, hides differences. **Differs from paper:** "ever suppressed" over all follow-up.
2. **Psychiatric history:** propensity model adding any psychiatry visit; retention and year-one suppression re-estimated with the new weights. Tests confounding by mental illness.
3. **Outside pharmacy:** excluding patients with a viral load ≤400 measured 90 or more days after their last fill of a drug in the current regimen, at any time in follow-up; main models re-estimated, unweighted and with the original weights. Tests whether fills elsewhere bias the outcomes.

## 10. Disclosure control

The data are clinic records under the study's IRB approval and Harris Health policy. No patient-level data, study IDs, or person-level dates are published, including in code: the manual regimen corrections are kept with the data. Results are those published in the paper; no new results from the real data are released here.

## 11. Limitations to address in reporting

- Observational design; unmeasured confounding, including clinicians' choice of protease inhibitors for patients expected to adhere poorly.
- The comparison mixes pill burden with drug class (efavirenz vs boosted protease inhibitors).
- Pharmacy fills measure collection, not ingestion, and miss fills elsewhere: PDC is a lower bound.
- Loss to follow-up cannot be distinguished from moving, transferring care, incarceration or death.
- Single clinic serving a largely uninsured, racially diverse population.
- Outcomes use different follow-up periods (see §7).

## 12. Reporting map

| Checklist item | Topic | Plan section |
|---|---|---|
| STROBE 4 | Study design | 2 |
| STROBE 5 / RECORD 5 | Setting, dates, data source | 3 |
| STROBE 6 / RECORD 6.1-6.3 | Eligibility, selection algorithms | 4, 5 |
| STROBE 7 / RECORD 7.1 | Variables, code lists and algorithms | 5, 7 |
| STROBE 8 | Measurement | 5, 7 |
| STROBE 9 | Bias | 8, 9, 11 |
| STROBE 12 | Statistical methods, missing data, sensitivity | 8, 9 |
| STROBE 13 / RECORD 13.1 | Participants, flow diagram | 4 |
| STROBE 19 / RECORD 19.1 | Limitations | 11 |
| RECORD 22.1 | Access to data and code | 3, 10 |

## References
