# Purpose: write the participant flow, baseline comparison, outcome and
#   sensitivity tables to tables/.
# Needs: tables_dir (setup.R); cohort_flow (06_cohort.R); baseline_tests,
#   weighted_balance (07_propensity.R); outcome_summary, outcome_models
#   (08_outcomes.R); psych_models, outside_pharmacy_models,
#   suppression_by_start_year (09_sensitivity.R).
# Produces: CSV files in tables/ (ignored by Git).

## ---- write-tables
dir.create(tables_dir, showWarnings = FALSE)

output_tables <- list(
  cohort_flow = cohort_flow,
  baseline_tests = baseline_tests,
  weighted_balance = weighted_balance,
  outcome_summary = outcome_summary,
  outcome_models = outcome_models,
  psych_models = psych_models,
  outside_pharmacy_models = outside_pharmacy_models,
  suppression_by_start_year = suppression_by_start_year
)

for (table_name in names(output_tables)) {
  write_csv(output_tables[[table_name]], file.path(tables_dir, str_c(table_name, ".csv")))
}
