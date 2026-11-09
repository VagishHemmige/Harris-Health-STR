# Purpose: count the pills of each drug a patient has on hand each day, decide
#   whether each day is covered by the full regimen, and define the daily
#   retention and viral suppression measures (Stata Step 8).
# Needs: fill_size_pills, vl_suppression_main, lab_window_days (setup.R);
#   count_pills_on_hand(), carry_over_pills(), vl_suppressed_on_day()
#   (functions.R); daily, daily_drugs (04_daily_regimen.R).
# Produces: analytic_days (one row per patient per day) — Stata's
#   "Data Analytic file".

## ---- number-days-within-regimen
# Stata's M: day 1, 2, 3 ... of each regimen for each patient.
daily_drugs <- daily_drugs |>
  arrange(studyid, drug_position, date) |>
  group_by(studyid, regimen_number, drug_position) |>
  mutate(day_in_regimen = row_number()) |>
  ungroup()

## ---- count-pills-per-regimen
# Regimens are processed in order, because the first day of a regimen can take
# over pills of the same drug left from the day before, the last day of the
# previous regimen.
pills_by_regimen <- list()

for (episode in sort(unique(daily_drugs$regimen_number))) {
  episode_drugs <- daily_drugs |> filter(regimen_number == episode)

  previous_regimen <- pills_by_regimen[[as.character(episode - 1)]]
  if (is.null(previous_regimen)) {
    previous_day <- tibble(studyid = numeric(), drug_name = character(),
                           previous_pills = numeric())
  } else {
    previous_day <- previous_regimen |>
      group_by(studyid) |>
      filter(date == max(date)) |>
      ungroup() |>
      select(studyid, drug_name, previous_pills = pills_on_hand)
  }

  first_day <- episode_drugs |>
    filter(day_in_regimen == 1) |>
    left_join(previous_day, by = c("studyid", "drug_name"),
              relationship = "many-to-many") |>
    group_by(studyid, drug_position) |>
    summarise(start_pills = carry_over_pills(first(pills_dispensed), previous_pills),
              .groups = "drop")

  pills_by_regimen[[as.character(episode)]] <- episode_drugs |>
    left_join(first_day, by = c("studyid", "drug_position"), relationship = "many-to-one") |>
    arrange(studyid, drug_position, date) |>
    group_by(studyid, drug_position) |>
    mutate(pills_on_hand = count_pills_on_hand(pills_dispensed, first(start_pills),
                                               fill_size_pills)) |>
    ungroup() |>
    select(-start_pills)
}

daily_drugs <- bind_rows(pills_by_regimen)

## ---- summarise-coverage-per-day
# A day is covered when every drug in the regimen is on hand, partially covered
# when some but not all are, and uncovered when none are.
day_coverage <- daily_drugs |>
  group_by(studyid, date) |>
  summarise(
    day_in_regimen = first(day_in_regimen),
    number_of_drugs = n(),
    any_drug_dispensed = any(pills_dispensed == fill_size_pills),
    day_covered = all(pills_on_hand > 0),
    day_partially_covered = any(pills_on_hand > 0) & !all(pills_on_hand > 0),
    .groups = "drop"
  ) |>
  mutate(day_uncovered = !day_covered & !day_partially_covered)

## ---- define-daily-outcomes
# Still in care: a CD4 and a viral load are both still to come. Virologically
# suppressed: see vl_suppressed_on_day() in functions.R.
analytic_days <- daily |>
  left_join(day_coverage, by = c("studyid", "date"), relationship = "one-to-one") |>
  mutate(
    still_in_care_cd4vl = !is.na(days_until_next_cd4) & !is.na(days_until_next_vl),
    vl_suppressed = vl_suppressed_on_day(lvcf_vl, days_since_last_vl,
                                         days_until_next_vl, next_vl,
                                         vl_suppression_main, lab_window_days)
  )
