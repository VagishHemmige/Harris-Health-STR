# Purpose: select the published cohort and build one row per patient with the
#   baseline values at ART start (first part of Stata "Final Analysis.do").
# Needs: manuscript_regimens, single_tablet_regimens, quarter_breaks, age_breaks,
#   vl_breaks, cd4_breaks (setup.R); count_patients() (functions.R);
#   analytic_days (05_adherence.R); baseline, insurance_categories
#   (02_labs_and_baseline.R).
# Produces: cohort_days (one row per patient per day from ART start),
#   patients (one row per patient) and cohort_flow (patients left after each step).

## ---- start-at-first-regimen
# Days before the first regimen are dropped. The first observation of a patient
# is the first day of regimen 1.
cohort_days <- analytic_days |>
  filter(!is.na(regimen_number)) |>
  left_join(baseline, by = "studyid") |>
  group_by(studyid) |>
  mutate(
    initial_regimen = first(regimen[regimen_number == 1]),
    initial_regimen_bid = first(bid_regimen[regimen_number == 1]),
    first_observation = day_in_regimen == 1 & regimen_number == 1
  ) |>
  ungroup()

cohort_flow <- count_patients(cohort_days, "Dispensed antiretrovirals in the study window")

## ---- apply-exclusions
# In the order Final Analysis.do applies them. Stata's `drop if x` also drops
# patients whose x is missing, so each filter keeps only an explicit "no".
cohort_days <- cohort_days |> filter(initial_regimen_bid %in% FALSE)
cohort_flow <- bind_rows(cohort_flow,
                         count_patients(cohort_days, "Starting regimen taken once daily"))

cohort_days <- cohort_days |> filter(initial_regimen %in% manuscript_regimens)
cohort_flow <- bind_rows(cohort_flow,
                         count_patients(cohort_days, "Started one of the three compared regimens"))

cohort_days <- cohort_days |> filter(prior_care_elsewhere %in% 0)
cohort_flow <- bind_rows(cohort_flow,
                         count_patients(cohort_days, "No prior HIV care elsewhere"))

cohort_days <- cohort_days |> filter(!is.na(insurance_status))
cohort_flow <- bind_rows(cohort_flow,
                         count_patients(cohort_days, "Insurance status recorded"))

## ---- define-exposure-and-time
cohort_days <- cohort_days |>
  group_by(studyid) |>
  mutate(art_start_date = first(date[first_observation])) |>
  ungroup() |>
  mutate(
    str = initial_regimen %in% single_tablet_regimens,
    on_initial_regimen = regimen_number == 1,
    art_start_year = year(art_start_date),
    days_since_art_start = as.numeric(date - art_start_date),
    quarter = cut(days_since_art_start, breaks = quarter_breaks, right = FALSE,
                  labels = FALSE) - 1,
    first_year = !is.na(quarter)
  )

## ---- build-patient-table
# One row per patient, with the baseline viral load and CD4 as the last values
# on or before the day ART started.
patients <- cohort_days |>
  filter(first_observation) |>
  transmute(
    studyid, str, initial_regimen, art_start_date, art_start_year,
    age, male, black, hispanic, idu, msm, hepc, primaryriskfactor, ethnicity,
    insurance_status, had_psych_visit,
    baseline_vl = lvcf_vl, baseline_cd4 = lvcf_cd4
  )

## ---- categorise-baseline-values
# The propensity model used "i3.Insurance": an indicator for the third
# insurance category in the whole insurance file, in character-code order
# (insurance_categories, 02_labs_and_baseline.R). The paper describes this
# covariate as insured vs uninsured.
patients <- patients |>
  mutate(
    age_group = cut(age, breaks = age_breaks, right = FALSE),
    baseline_vl_group = cut(baseline_vl, breaks = vl_breaks, right = FALSE,
                            dig.lab = 8),
    baseline_cd4_group = cut(baseline_cd4, breaks = cd4_breaks, right = FALSE,
                             dig.lab = 8),
    insurance_category_3 = insurance_status == insurance_categories[3]
  )
