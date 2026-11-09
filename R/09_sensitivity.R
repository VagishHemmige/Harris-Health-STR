# Purpose: the sensitivity analyses reported in the paper: a lower viral load
#   threshold after 2008, a propensity model that adds psychiatry visits, and
#   excluding patients who may have filled elsewhere (Final Analysis.do).
# Needs: vl_suppression_main, vl_suppression_later, lab_window_days,
#   missed_fill_days (setup.R); vl_suppressed_on_day(), compare_categorical(),
#   odds_ratio_for_str() (functions.R); cohort_days (06_cohort.R); patients
#   (08_outcomes.R).
# Produces: suppression_by_start_year, str_by_start_year, psych_models,
#   outside_pharmacy_summary and outside_pharmacy_models.

## ---- suppression-threshold-by-year
# 400 copies/mL for patients starting ART in 2008 and 50 copies/mL afterwards.
# As in the Stata code, "ever suppressed" here uses all follow-up, not year one.
suppression_by_year_threshold <- cohort_days |>
  mutate(
    threshold = if_else(art_start_year == 2008, vl_suppression_main, vl_suppression_later),
    vl_suppressed_year_threshold = vl_suppressed_on_day(
      lvcf_vl, days_since_last_vl, days_until_next_vl, next_vl,
      threshold, lab_window_days
    )
  ) |>
  group_by(studyid) |>
  summarise(vl_suppressed_year_threshold = any(vl_suppressed_year_threshold),
            .groups = "drop")

patients <- patients |>
  left_join(suppression_by_year_threshold, by = "studyid")

suppression_by_start_year <- patients |>
  group_by(art_start_year, str) |>
  summarise(patients = n(), suppressed = sum(vl_suppressed_year_threshold),
            percent = 100 * suppressed / patients, .groups = "drop")

## ---- str-by-start-year
# Stata: logistic InitialRegimenSTR i.YearofARTInitiation
str_by_start_year <- glm(str ~ factor(art_start_year), data = patients,
                         family = binomial())

## ---- add-psych-visits-to-propensity
# The paper reports that adding psychiatry clinic visits to the propensity
# model did not meaningfully change the odds ratios. Final Analysis.do computed
# these weights (IPW2) but its next two models used the original weights; here
# the new weights are used, as the paper describes.
propensity_model_psych <- update(propensity_model, . ~ . + had_psych_visit)

patients <- patients |>
  mutate(
    propensity_score_psych = predict(propensity_model_psych, newdata = patients,
                                     type = "response"),
    ipw_psych = if_else(str, 1 / propensity_score_psych, 1 / (1 - propensity_score_psych))
  )

psych_models <- bind_rows(
  odds_ratio_for_str(patients, "retained_year_one", weight = "ipw_psych"),
  odds_ratio_for_str(patients, "vl_suppressed_year_one", weight = "ipw_psych")
)

## ---- flag-possible-outside-pharmacy
# A suppressed viral load (<= 400) measured 90 or more days after the last fill
# of a drug in the current regimen suggests medication from another pharmacy.
# Stata treats a missing "days since" (no fill yet on the current regimen) as
# larger than 90, so such a day can be flagged; coalesce(..., TRUE) does the same.
fill_gaps <- cohort_days |>
  arrange(studyid, date) |>
  mutate(last_dispense_date = if_else(any_drug_dispensed, date, as.Date(NA))) |>
  group_by(studyid) |>
  fill(last_dispense_date, .direction = "down") |>
  ungroup() |>
  mutate(
    days_since_last_dispense = as.numeric(date - last_dispense_date),
    suppressed_without_fill = coalesce(current_vl <= vl_suppression_main, FALSE) &
      coalesce(days_since_last_dispense >= missed_fill_days, TRUE)
  )

outside_pharmacy <- fill_gaps |>
  group_by(studyid) |>
  summarise(possible_outside_pharmacy = any(suppressed_without_fill), .groups = "drop")

patients <- patients |>
  left_join(outside_pharmacy, by = "studyid")

# Stata: tab SwitchesPharmacy InitialRegimenSTR if FirstObservationOfSubject, chi2
outside_pharmacy_summary <- patients |>
  count(str, possible_outside_pharmacy)
outside_pharmacy_test <- compare_categorical(patients, "possible_outside_pharmacy")

## ---- exclude-possible-outside-pharmacy
# The paper reports repeating the main analyses without these patients. Final
# Analysis.do flags them but does not contain those models, so here the main
# models are refitted on the published cohort without the flagged patients.
patients_filling_here <- patients |> filter(!possible_outside_pharmacy)

outside_pharmacy_models <- list()
for (outcome in c("retained_year_one", "vl_suppressed_year_one")) {
  outside_pharmacy_models[[outcome]] <- bind_rows(
    odds_ratio_for_str(patients_filling_here, outcome),
    odds_ratio_for_str(patients_filling_here, outcome, weight = "ipw")
  )
}
outside_pharmacy_models <- bind_rows(outside_pharmacy_models)
