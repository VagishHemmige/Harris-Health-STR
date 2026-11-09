# Purpose: define each patient's outcomes and compare STR with multi-tablet
#   regimens, unadjusted and with inverse probability weights (Final Analysis.do;
#   the paper's Table 3).
# Needs: pdc_adherent, retention_min_gap_days (setup.R); odds_ratio_for_str()
#   (functions.R); cohort_days (06_cohort.R); patients with ipw (07_propensity.R).
# Produces: patients with outcome columns added, outcome_summary and
#   outcome_models.

## ---- define-retention
# HRSA definition: at least two viral loads in the first year after ART start
# (days 0-364), more than 90 days apart.
retention <- cohort_days |>
  filter(first_year, !is.na(current_vl)) |>
  group_by(studyid) |>
  summarise(
    first_year_vl_tests = n(),
    first_to_last_vl_days = as.numeric(max(date) - min(date)),
    .groups = "drop"
  )

## ---- define-patient-outcomes
# Note the follow-up each outcome uses, which differs between outcomes in the
# original code: suppression in year one uses days 0-364; suppression on the
# initial regimen and proportion of days covered use all follow-up to the end
# of 2013.
patient_outcomes <- cohort_days |>
  group_by(studyid) |>
  summarise(
    vl_suppressed_year_one = any(vl_suppressed[first_year]),
    vl_suppressed_on_initial_regimen = any(vl_suppressed & on_initial_regimen),
    proportion_days_covered = mean(day_covered),
    proportion_days_covered_initial = mean(day_covered & on_initial_regimen),
    changed_regimen = n_distinct(regimen_number) > 1,
    .groups = "drop"
  )

patients <- patients |>
  left_join(retention, by = "studyid") |>
  left_join(patient_outcomes, by = "studyid") |>
  mutate(
    retained_year_one = coalesce(first_year_vl_tests >= 2 &
                                   first_to_last_vl_days > retention_min_gap_days, FALSE),
    adherent_pdc_80 = proportion_days_covered >= pdc_adherent,
    adherent_pdc_80_initial = proportion_days_covered_initial >= pdc_adherent
  )

## ---- suppression-at-switch
# Were patients suppressed on the day they switched to a second regimen?
suppression_at_switch <- cohort_days |>
  filter(regimen_number == 2, day_in_regimen == 1) |>
  count(str, vl_suppressed)

## ---- summarise-outcomes
outcome_names <- c("retained_year_one", "vl_suppressed_year_one",
                   "vl_suppressed_on_initial_regimen", "adherent_pdc_80",
                   "adherent_pdc_80_initial", "changed_regimen")

outcome_summary <- patients |>
  select(str, all_of(outcome_names)) |>
  pivot_longer(-str, names_to = "outcome", values_to = "achieved") |>
  group_by(outcome, str) |>
  summarise(patients = n(), achieved = sum(achieved, na.rm = TRUE),
            percent = 100 * achieved / patients, .groups = "drop")

## ---- fit-outcome-models
outcome_models <- list()
for (outcome in outcome_names) {
  outcome_models[[outcome]] <- bind_rows(
    odds_ratio_for_str(patients, outcome),
    odds_ratio_for_str(patients, outcome, weight = "ipw")
  )
}
outcome_models <- bind_rows(outcome_models)
