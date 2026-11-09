# Purpose: build the publication tables (Table 1, baseline characteristics
#   before and after weighting; Table 2, outcomes with odds ratios) with
#   gtsummary and save them as Word and HTML files, and write every analysis
#   result to a CSV file.
# Translates: no Stata. The Stata wrote results to log files, and the tables in
#   the paper were typed from them.
# Needs: tables_dir (setup.R); odds_ratio_for_str() (functions.R);
#   cohort_flow (06_cohort.R); patients with ipw, baseline_tests,
#   insurance_model, weighted_balance, weighted_categories (07_propensity.R);
#   outcome_names, outcome_summary, outcome_models, suppression_at_switch
#   (08_outcomes.R); suppression_by_start_year, str_by_start_year, psych_test,
#   psych_models, outside_pharmacy_summary, outside_pharmacy_test,
#   outside_pharmacy_models (09_sensitivity.R).
# Produces: in tables/ (ignored by Git): table_1_baseline and table_2_outcomes
#   as .docx and .html, and one CSV file per result.

## ---- prepare-table-data
# One label per variable, used by both tables, and the regimen group as a
# labelled factor so the single tablet comes first.
baseline_variables <- c("age", "male", "ethnicity", "primaryriskfactor", "hepc",
                        "insurance_status", "baseline_vl_group", "baseline_cd4_group")

table_labels <- list(
  age ~ "Age, years",
  male ~ "Male",
  ethnicity ~ "Race/ethnicity",
  primaryriskfactor ~ "HIV risk factor",
  hepc ~ "Hepatitis C",
  insurance_status ~ "Insurance",
  baseline_vl_group ~ "Viral load before ART, copies/mL",
  baseline_cd4_group ~ "CD4 count before ART, cells/µL",
  retained_year_one ~ "Retained in care in year one",
  vl_suppressed_year_one ~ "Suppressed at least once in year one",
  vl_suppressed_on_initial_regimen ~ "Suppressed while on the starting regimen",
  adherent_pdc_80 ~ "Days covered at least 80%",
  adherent_pdc_80_initial ~ "Days covered at least 80%, starting regimen",
  changed_regimen ~ "Changed regimen in year one"
)

table_data <- patients |>
  mutate(regimen = factor(if_else(str, "Single tablet", "Multi-tablet"),
                          levels = c("Single tablet", "Multi-tablet")))

## ---- table-1-baseline
# Before weighting: counts and percentages, mean (SD) for age, and the tests
# Final Analysis.do ran (Pearson chi-squared without continuity correction;
# t-test with equal variances).
table_1_unweighted <- table_data |>
  tbl_summary(
    by = regimen,
    include = all_of(baseline_variables),
    label = table_labels,
    statistic = list(all_continuous() ~ "{mean} ({sd})"),
    missing_text = "Missing"
  ) |>
  add_overall() |>
  add_p(
    test = list(all_categorical() ~ "chisq.test.no.correct", age ~ "t.test"),
    test.args = list(age ~ list(var.equal = TRUE))
  )

# After weighting: weighted percentages and means among patients with a
# weight, as Stata's [aw=IPW] tables gave; no tests, as in Stata.
weighted_design <- svydesign(ids = ~1, weights = ~ipw,
                             data = filter(table_data, !is.na(ipw)))

table_1_weighted <- weighted_design |>
  tbl_svysummary(
    by = regimen,
    include = all_of(baseline_variables),
    label = table_labels,
    statistic = list(all_continuous() ~ "{mean} ({sd})",
                     all_categorical() ~ "{p}%"),
    missing = "no"
  )

table_1 <- tbl_merge(
  list(table_1_unweighted, table_1_weighted),
  tab_spanner = c("**Before weighting**", "**After weighting**")
) |>
  bold_labels() |>
  modify_caption("**Table 1. Patient characteristics by starting regimen**")

## ---- table-2-outcomes
# Each outcome by group, with the odds ratios from odds_ratio_for_str() added
# as two more columns: unadjusted and inverse probability weighted.
format_odds_ratio <- function(result) {
  sprintf("%.2f (%.2f-%.2f)", result$odds_ratio, result$conf_low, result$conf_high)
}

odds_ratio_columns <- function(data, variable, ...) {
  tibble(
    unadjusted_or = format_odds_ratio(odds_ratio_for_str(data, variable)),
    weighted_or = format_odds_ratio(odds_ratio_for_str(data, variable, weight = "ipw"))
  )
}

table_2 <- table_data |>
  tbl_summary(
    by = regimen,
    include = all_of(outcome_names),
    label = table_labels,
    statistic = list(all_dichotomous() ~ "{n} ({p}%)"),
    missing = "no"
  ) |>
  add_stat(fns = everything() ~ odds_ratio_columns) |>
  modify_header(
    unadjusted_or = "**Odds ratio (95% CI)**",
    weighted_or = "**Weighted odds ratio (95% CI)**"
  ) |>
  bold_labels() |>
  modify_caption("**Table 2. Outcomes in the first year by starting regimen**")

## ---- save-publication-tables
# Word files go straight into a manuscript; HTML files are for checking.
dir.create(tables_dir, showWarnings = FALSE)

publication_tables <- list(table_1_baseline = table_1, table_2_outcomes = table_2)

for (table_name in names(publication_tables)) {
  publication_tables[[table_name]] |>
    as_flex_table() |>
    flextable::save_as_docx(path = file.path(tables_dir, str_c(table_name, ".docx")))
  publication_tables[[table_name]] |>
    as_gt() |>
    gt::gtsave(file.path(tables_dir, str_c(table_name, ".html")))
}

## ---- write-tables
# Every result as a CSV file, including those not in the two tables, so each
# number on the Published results page can be found in tables/.
output_tables <- list(
  cohort_flow = cohort_flow,
  baseline_tests = baseline_tests,
  insurance_model = tidy(insurance_model, exponentiate = TRUE, conf.int = TRUE),
  weighted_balance = weighted_balance,
  weighted_categories = weighted_categories,
  outcome_summary = outcome_summary,
  outcome_models = outcome_models,
  suppression_at_switch = suppression_at_switch,
  suppression_by_start_year = suppression_by_start_year,
  str_by_start_year = tidy(str_by_start_year, exponentiate = TRUE, conf.int = TRUE),
  psych_test = psych_test,
  psych_models = psych_models,
  outside_pharmacy_summary = outside_pharmacy_summary,
  outside_pharmacy_test = outside_pharmacy_test,
  outside_pharmacy_models = outside_pharmacy_models
)

for (table_name in names(output_tables)) {
  write_csv(output_tables[[table_name]], file.path(tables_dir, str_c(table_name, ".csv")))
}
