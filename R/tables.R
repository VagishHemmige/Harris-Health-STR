# Purpose: build the publication tables (Table 1, baseline characteristics
#   before and after weighting; Table 2, outcomes with odds ratios) with
#   gtsummary and save them as Word and HTML files, and write every analysis
#   result to a CSV file.
# Translates: no Stata. The Stata wrote results to log files, and the tables in
#   the paper were typed from them.
# Needs: tables_dir (setup.R); tidy_wald_z() (functions.R);
#   cohort_flow (06_cohort.R); patients with ipw, baseline_tests,
#   insurance_model, weighted_balance, weighted_categories (07_propensity.R);
#   outcome_names, outcome_summary, outcome_models, suppression_at_switch
#   (08_outcomes.R); suppression_by_start_year, str_by_start_year, psych_test,
#   psych_models, outside_pharmacy_summary, outside_pharmacy_test,
#   outside_pharmacy_models (09_sensitivity.R).
# Produces: in tables/ (ignored by Git): table_1_baseline and table_2_outcomes
#   as .docx and .html (and as CSV, for the automatic check), and one CSV
#   file per result.

## ---- prepare-table-data
# The label each variable should have in the paper, and the regimen group as a
# labelled factor so the single tablet comes first. Every call names its
# package, as the reporting guidance asks.
baseline_variables <- c("age", "male", "ethnicity", "primaryriskfactor", "hepc",
                        "insurance_status", "baseline_vl_group", "baseline_cd4_group")

baseline_labels <- list(
  age ~ "Age, years",
  male ~ "Male",
  ethnicity ~ "Race/ethnicity",
  primaryriskfactor ~ "HIV risk factor",
  hepc ~ "Hepatitis C",
  insurance_status ~ "Insurance",
  baseline_vl_group ~ "Viral load before ART, copies/mL",
  baseline_cd4_group ~ "CD4 count before ART, cells/µL"
)

outcome_labels <- list(
  retained_year_one ~ "Retained in care in year one",
  vl_suppressed_year_one ~ "Suppressed at least once in year one",
  vl_suppressed_on_initial_regimen ~ "Suppressed while on the starting regimen",
  adherent_pdc_80 ~ "Days covered at least 80%",
  adherent_pdc_80_initial ~ "Days covered at least 80%, starting regimen",
  changed_regimen ~ "Changed regimen in year one"
)

# Readable category names in place of the codes in the extracts. The viral
# load and CD4 groups are intervals made by cut() ("[1000,10000)"), shown as
# "1,000-9,999"; the top group, whose upper limit in setup.R is only a large
# number, as "500 or more".
interval_label <- function(group) {
  limits <- stringr::str_match(as.character(group), "^\\[([0-9.e+]+),([0-9.e+]+)\\)$")
  low <- as.numeric(limits[, 2])
  high <- as.numeric(limits[, 3])
  label <- dplyr::if_else(
    low == max(low, na.rm = TRUE),
    stringr::str_c(format(low, big.mark = ",", scientific = FALSE, trim = TRUE), " or more"),
    stringr::str_c(format(low, big.mark = ",", scientific = FALSE, trim = TRUE), "-",
                   format(high - 1, big.mark = ",", scientific = FALSE, trim = TRUE))
  )
  factor(label, levels = unique(label[order(low)]))
}

table_data <- patients |>
  dplyr::mutate(
    regimen = factor(dplyr::if_else(str, "Single tablet", "Multi-tablet"),
                     levels = c("Single tablet", "Multi-tablet")),
    ethnicity = dplyr::recode(ethnicity, B = "Black", H = "Hispanic", W = "White"),
    primaryriskfactor = dplyr::recode(primaryriskfactor,
                                      HET = "Heterosexual contact",
                                      IDU = "Injection drug use",
                                      MSM = "Men who have sex with men",
                                      `MSM&IDU` = "Men who have sex with men and injection drug use"),
    baseline_vl_group = interval_label(baseline_vl_group),
    baseline_cd4_group = interval_label(baseline_cd4_group)
  )

weighted_design <- survey::svydesign(ids = ~1, weights = ~ipw,
                                     data = dplyr::filter(table_data, !is.na(ipw)))

## ---- table-1-baseline
# Before weighting: n (%) for categories, mean (SD) for age, the number missing
# for every variable, and the tests Final Analysis.do ran (Pearson
# chi-squared without continuity correction; t-test with equal variances).
table_1_unweighted <- table_data |>
  gtsummary::tbl_summary(
    by = regimen,
    include = tidyselect::all_of(baseline_variables),
    label = baseline_labels,
    statistic = list(gtsummary::all_continuous() ~ "{mean} ({sd})",
                     gtsummary::all_categorical() ~ "{n} ({p}%)"),
    missing = "always",
    missing_stat = "{N_miss}",
    missing_text = "Missing"
  ) |>
  gtsummary::add_overall() |>
  gtsummary::add_p(
    test = list(gtsummary::all_categorical() ~ "chisq.test.no.correct", age ~ "t.test"),
    test.args = list(age ~ list(var.equal = TRUE))
  )

# After weighting: weighted percentages and means among patients with a
# weight, as Stata's [aw=IPW] tables gave; no tests, as in Stata.
table_1_weighted <- weighted_design |>
  gtsummary::tbl_svysummary(
    by = regimen,
    include = tidyselect::all_of(baseline_variables),
    label = baseline_labels,
    statistic = list(gtsummary::all_continuous() ~ "{mean} ({sd})",
                     gtsummary::all_categorical() ~ "{p}%"),
    missing = "no"
  ) |>
  # The header shows patients, not the sum of their weights.
  gtsummary::modify_header(gtsummary::all_stat_cols() ~ "**{level}**  \nN = {n_unweighted}")

table_1 <- gtsummary::tbl_merge(
  list(table_1_unweighted, table_1_weighted),
  tab_spanner = c("**Before weighting**", "**After weighting**")
) |>
  gtsummary::bold_labels() |>
  gtsummary::modify_caption("**Table 1. Patient characteristics by starting regimen**")

## ---- table-2-outcomes
# Three tables merged side by side: each outcome by group; the unadjusted odds
# ratio (logistic regression); and the weighted odds ratio (survey-weighted
# logistic regression, Stata's [pw=IPW]). tbl_uvregression() with x = str fits
# one model per outcome. tidy_wald_z() gives Stata's Wald intervals. The N
# column shows how many patients each unadjusted model used. For the weighted
# models gtsummary would show the sum of the weights, not patients, so N is
# hidden there and a note says who is left out.
outcome_counts <- table_data |>
  gtsummary::tbl_summary(
    by = regimen,
    include = tidyselect::all_of(outcome_names),
    label = outcome_labels,
    statistic = list(gtsummary::all_dichotomous() ~ "{n} ({p}%)"),
    missing = "always",
    missing_stat = "{N_miss}",
    missing_text = "Missing"
  )

unadjusted_models <- table_data |>
  dplyr::select(str, tidyselect::all_of(outcome_names)) |>
  gtsummary::tbl_uvregression(
    method = stats::glm,
    method.args = list(family = stats::binomial()),
    x = str,
    exponentiate = TRUE,
    tidy_fun = tidy_wald_z,
    label = outcome_labels,
    show_single_row = str
  )

weighted_models <- weighted_design |>
  gtsummary::tbl_uvregression(
    method = survey::svyglm,
    method.args = list(family = stats::quasibinomial()),
    x = str,
    include = tidyselect::all_of(outcome_names),
    exponentiate = TRUE,
    tidy_fun = tidy_wald_z,
    label = outcome_labels,
    show_single_row = str,
    hide_n = TRUE
  )

table_2 <- gtsummary::tbl_merge(
  list(outcome_counts, unadjusted_models, weighted_models),
  tab_spanner = c("**Patients**", "**Unadjusted**", "**Weighted**")
) |>
  gtsummary::bold_labels() |>
  gtsummary::modify_source_note(
    "Weighted: inverse probability of treatment weights; patients without a weight (a covariate missing) are left out."
  ) |>
  gtsummary::modify_caption("**Table 2. Outcomes in the first year by starting regimen**")

## ---- save-publication-tables
# Word files go straight into a manuscript; HTML files are for checking; a CSV
# of each formatted table lets the automatic check print it.
dir.create(tables_dir, showWarnings = FALSE)

publication_tables <- list(table_1_baseline = table_1, table_2_outcomes = table_2)

for (table_name in names(publication_tables)) {
  publication_tables[[table_name]] |>
    gtsummary::as_flex_table() |>
    flextable::save_as_docx(path = file.path(tables_dir, stringr::str_c(table_name, ".docx")))
  publication_tables[[table_name]] |>
    gtsummary::as_gt() |>
    gt::gtsave(file.path(tables_dir, stringr::str_c(table_name, ".html")))
  publication_tables[[table_name]] |>
    gtsummary::as_tibble(col_labels = TRUE) |>
    readr::write_csv(file.path(tables_dir, stringr::str_c(table_name, "_formatted.csv")))
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
