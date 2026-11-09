# Purpose: reusable helper functions. Each takes its inputs as arguments.
# Needs: setup.R. Produces: functions only.

## ---- read-source-csv
# Stata: insheet using "<file>", comma
read_source_csv <- function(data_dir, file_name) {
  read_csv(file.path(data_dir, file_name), show_col_types = FALSE, guess_max = 100000)
}

## ---- read-regimen-corrections
# Reads the manual regimen corrections, if the file exists. Each row says: for
# this patient, between first_date and last_date (either may be blank, meaning
# open-ended), the regimen is really `regimen`. Later rows win, as later
# `replace` lines did in Stata.
read_regimen_corrections <- function(path) {
  if (!file.exists(path)) {
    return(tibble(studyid = numeric(), first_date = as.Date(character()),
                  last_date = as.Date(character()), regimen = character()))
  }
  read_csv(path, show_col_types = FALSE, col_types = cols(
    studyid = col_double(), first_date = col_date(), last_date = col_date(),
    regimen = col_character()
  ))
}

## ---- make-regimen-name
# Joins the drugs filled on one day into a regimen name, in alphabetical order,
# as Stata did by sorting on drugname and concatenating with "/". A drug filled
# twice on the same day appears twice, as it did in Stata.
make_regimen_name <- function(drug_names) {
  str_c(str_sort(drug_names, locale = "C"), collapse = "/")
}

## ---- apply-regimen-corrections
# Replaces the regimen named on a fill date when a correction covers that
# patient and date. If several corrections cover the same date, the last one wins.
apply_regimen_corrections <- function(dispense_regimens, corrections) {
  matched <- corrections |>
    mutate(correction_order = row_number()) |>
    inner_join(dispense_regimens |> select(studyid, dispense_date),
               by = "studyid", relationship = "many-to-many") |>
    filter(is.na(first_date) | dispense_date >= first_date,
           is.na(last_date) | dispense_date <= last_date) |>
    group_by(studyid, dispense_date) |>
    slice_max(correction_order, n = 1) |>
    ungroup() |>
    select(studyid, dispense_date, corrected_regimen = regimen)

  dispense_regimens |>
    left_join(matched, by = c("studyid", "dispense_date")) |>
    mutate(regimen = coalesce(corrected_regimen, regimen)) |>
    select(-corrected_regimen)
}

## ---- count-pills-on-hand
# Pills of one drug on hand each day of one regimen, as in Stata Step 8.
# Day 1 starts with start_pills. Each later day: a 30-pill fill when the patient
# had none left gives 30; otherwise yesterday's pills plus today's fill, less one
# pill taken, never below zero. Pills therefore build up when a patient refills
# early.
# Written as a loop because each day depends on the day before.
count_pills_on_hand <- function(pills_dispensed, start_pills, fill_size) {
  pills <- numeric(length(pills_dispensed))
  pills[1] <- start_pills
  for (day in seq_along(pills_dispensed)[-1]) {
    if (pills_dispensed[day] == fill_size && pills[day - 1] == 0) {
      pills[day] <- fill_size
    } else {
      pills[day] <- max(0, pills_dispensed[day] + pills[day - 1] - 1)
    }
  }
  pills
}

## ---- carry-over-pills
# On the first day of a new regimen, pills of the same drug left over from the
# previous regimen are added (less the one taken that day), once for each
# matching drug in the previous regimen, as the nested Stata loop did.
# previous_pills is NA when the drug was not in the previous regimen.
carry_over_pills <- function(pills_dispensed, previous_pills) {
  pills <- pills_dispensed
  for (leftover in previous_pills[!is.na(previous_pills)]) {
    pills <- max(0, pills + leftover - 1)
  }
  pills
}

## ---- vl-suppressed-on-day
# A day counts as virologically suppressed when the last viral load was at or
# below the threshold and it was either measured within the last 90 days, or the
# next one comes within 90 days and is also at or below the threshold (Stata
# Step 8). Stata treats comparisons with missing values as false; coalesce()
# does the same here.
vl_suppressed_on_day <- function(last_vl, days_since_last_vl, days_until_next_vl,
                                 next_vl, threshold, window_days) {
  suppressed <- last_vl <= threshold &
    (days_since_last_vl <= window_days |
       (days_until_next_vl <= window_days & next_vl <= threshold))
  coalesce(suppressed, FALSE)
}

## ---- count-patients
# One row for the participant flow: the step and how many patients remain.
count_patients <- function(data, step) {
  tibble(step = step, patients = n_distinct(data$studyid))
}

## ---- compare-groups
# Baseline comparison between the STR and multi-tablet groups, as the Stata
# tab ..., chi2 / ttest / ranksum commands did. Stata's chi2 has no continuity
# correction, ttest assumes equal variances and ranksum uses the normal
# approximation.
compare_categorical <- function(patients, variable) {
  counts <- table(patients[[variable]], patients$str)
  tibble(variable = variable, test = "Pearson chi-squared",
         p_value = chisq.test(counts, correct = FALSE)$p.value)
}

compare_continuous <- function(patients, variable) {
  values <- patients[[variable]]
  t_test <- t.test(values ~ patients$str, var.equal = TRUE)
  rank_test <- wilcox.test(values ~ patients$str, exact = FALSE, correct = FALSE)
  tibble(
    variable = variable,
    test = c("t-test", "Wilcoxon rank-sum"),
    p_value = c(t_test$p.value, rank_test$p.value)
  )
}

## ---- odds-ratio-for-str
# Odds ratio for an outcome comparing STR with multi-tablet regimens.
# Without weights: ordinary logistic regression (Stata: logistic y str).
# With weights: survey-weighted logistic regression, which gives the robust
# standard errors Stata reports for [pw=IPW].
odds_ratio_for_str <- function(patients, outcome, weight = NULL) {
  model_formula <- reformulate("str", response = outcome)
  model_data <- patients |> filter(!is.na(.data[[outcome]]))
  if (is.null(weight)) {
    model <- glm(model_formula, data = model_data, family = binomial())
    label <- "Unadjusted"
  } else {
    model_data <- model_data |> filter(!is.na(.data[[weight]]))
    design <- svydesign(ids = ~1, weights = reformulate(weight), data = model_data)
    model <- svyglm(model_formula, design = design, family = quasibinomial())
    label <- str_c("Weighted (", weight, ")")
  }
  # Wald confidence intervals and z-test p-values on the log-odds scale, as
  # Stata reports (svyglm's own p-values use the t distribution).
  tidy(model) |>
    filter(term == "strTRUE") |>
    transmute(outcome = outcome, analysis = label, patients = nrow(model_data),
              odds_ratio = exp(estimate),
              conf_low = exp(estimate - qnorm(0.975) * std.error),
              conf_high = exp(estimate + qnorm(0.975) * std.error),
              p_value = 2 * pnorm(-abs(estimate / std.error)))
}
