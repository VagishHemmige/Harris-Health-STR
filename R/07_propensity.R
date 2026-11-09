# Purpose: compare the two groups at baseline, fit the propensity score model and
#   compute inverse probability of treatment weights (Final Analysis.do).
# Needs: compare_categorical(), compare_continuous(), weighted_distribution()
#   (functions.R); patients (06_cohort.R).
# Produces: baseline_tests, propensity_model, patients with propensity_score and
#   ipw added, weighted_balance and weighted_categories.

## ---- test-baseline-differences
# Stata: tab InitialRegimenSTR <variable> if FirstObservationOfSubject, chi2
# and ttest / ranksum for age, viral load and CD4.
baseline_tests <- bind_rows(
  compare_categorical(patients, "male"),
  compare_categorical(patients, "hepc"),
  compare_categorical(patients, "ethnicity"),
  compare_categorical(patients, "primaryriskfactor"),
  compare_categorical(patients, "insurance_status"),
  compare_categorical(patients, "age_group"),
  compare_categorical(patients, "baseline_vl_group"),
  compare_categorical(patients, "baseline_cd4_group"),
  compare_continuous(patients, "age"),
  compare_continuous(patients, "baseline_vl"),
  compare_continuous(patients, "baseline_cd4")
)

## ---- insurance-and-str
# Final Analysis.do also asked whether insurance predicted receiving an STR.
insurance_model <- glm(str ~ insurance_status, data = patients, family = binomial())

## ---- fit-propensity-model
# The probability of starting an STR given the covariates listed in the paper.
# Patients missing any covariate get no propensity score and drop out of the
# weighted analyses, as in Stata.
propensity_model <- glm(
  str ~ hepc + male + black + hispanic + idu + msm + age_group +
    baseline_vl_group + baseline_cd4_group + insurance_category_3,
  data = patients, family = binomial()
)

## ---- compute-weights
# Inverse probability of treatment weights: 1 / P(STR) for STR patients and
# 1 / P(multi-tablet) for the others.
patients <- patients |>
  mutate(
    propensity_score = predict(propensity_model, newdata = patients, type = "response"),
    ipw = if_else(str, 1 / propensity_score, 1 / (1 - propensity_score))
  )

## ---- check-weighted-balance
# Stata repeated the baseline tables with [aw=IPW]. After weighting, the two
# groups should look alike on every covariate in the model.
weighted_balance <- patients |>
  filter(!is.na(ipw)) |>
  group_by(str) |>
  summarise(
    patients = n(),
    male = weighted.mean(male, ipw, na.rm = TRUE),
    black = weighted.mean(black, ipw, na.rm = TRUE),
    hispanic = weighted.mean(hispanic, ipw, na.rm = TRUE),
    idu = weighted.mean(idu, ipw, na.rm = TRUE),
    msm = weighted.mean(msm, ipw, na.rm = TRUE),
    hepc = weighted.mean(hepc, ipw, na.rm = TRUE),
    insurance_category_3 = weighted.mean(insurance_category_3, ipw, na.rm = TRUE),
    mean_age = weighted.mean(age, ipw, na.rm = TRUE),
    mean_baseline_cd4 = weighted.mean(baseline_cd4, ipw, na.rm = TRUE),
    .groups = "drop"
  )

## ---- check-weighted-category-balance
# Stata also tabulated each categorical covariate with [aw=IPW]: ethnicity,
# risk factor, age group, baseline viral load and CD4 groups, and insurance.
# Weighted percentages in each category, by group.
balance_variables <- c("ethnicity", "primaryriskfactor", "age_group",
                       "baseline_vl_group", "baseline_cd4_group", "insurance_status")

weighted_categories <- list()
for (variable in balance_variables) {
  weighted_categories[[variable]] <- weighted_distribution(patients, variable, "ipw")
}
weighted_categories <- bind_rows(weighted_categories)
