# Purpose: give every patient one row per calendar day of the study window and
#   attach the CD4 and viral load results to the days they were measured,
#   with the last value carried forward and the time since the last and until
#   the next test (Stata Step 5).
# Needs: study_start, study_end (setup.R); baseline, cd4, viral_load
#   (02_labs_and_baseline.R).
# Produces: person_days (one row per patient per day, 2008-2013).

## ---- expand-to-days
study_days <- tibble(date = seq(study_start, study_end, by = "day"))

person_days <- baseline |>
  select(studyid) |>
  cross_join(study_days)

## ---- attach-lab-results
# If a patient had two results on one day, Stata kept whichever its sort put
# last, which is arbitrary; here the last one in the file is kept.
cd4_by_day <- cd4 |>
  group_by(studyid, lab_date) |>
  summarise(current_cd4 = last(cd4), .groups = "drop")

vl_by_day <- viral_load |>
  group_by(studyid, lab_date) |>
  summarise(current_vl = last(vl), .groups = "drop")

person_days <- person_days |>
  left_join(cd4_by_day, by = c("studyid", "date" = "lab_date")) |>
  left_join(vl_by_day, by = c("studyid", "date" = "lab_date"))

## ---- carry-lab-values
# Last value carried forward (filled down) and next value (filled up), with the
# dates they come from, so that days since the last test and days until the
# next one can be counted. Before a patient's first test the "last" values are
# missing; after the last test the "next" values are missing.
person_days <- person_days |>
  mutate(
    last_cd4_date = if_else(is.na(current_cd4), as.Date(NA), date),
    last_vl_date = if_else(is.na(current_vl), as.Date(NA), date),
    lvcf_cd4 = current_cd4,
    lvcf_vl = current_vl,
    next_cd4_date = last_cd4_date,
    next_vl_date = last_vl_date,
    next_cd4 = current_cd4,
    next_vl = current_vl
  ) |>
  arrange(studyid, date) |>
  group_by(studyid) |>
  fill(last_cd4_date, last_vl_date, lvcf_cd4, lvcf_vl, .direction = "down") |>
  fill(next_cd4_date, next_vl_date, next_cd4, next_vl, .direction = "up") |>
  ungroup()

## ---- count-days-between-tests
person_days <- person_days |>
  mutate(
    days_since_last_cd4 = as.numeric(date - last_cd4_date),
    days_since_last_vl = as.numeric(date - last_vl_date),
    days_until_next_cd4 = as.numeric(next_cd4_date - date),
    days_until_next_vl = as.numeric(next_vl_date - date),
    cd4_gap_days = days_until_next_cd4 + days_since_last_cd4,
    vl_gap_days = days_until_next_vl + days_since_last_vl
  ) |>
  select(-last_cd4_date, -last_vl_date, -next_cd4_date, -next_vl_date)
