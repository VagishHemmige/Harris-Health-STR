# Purpose: put each patient's current regimen on every day, list the drugs in it,
#   and mark the days each drug was dispensed (Stata Steps 6 and 7).
# Needs: fill_size_pills (setup.R); fills, regimen_episodes (01_regimens.R);
#   person_days (03_person_days.R).
# Produces: daily (one row per patient per day, with the current regimen) and
#   daily_drugs (one row per patient per day per drug in the current regimen).

## ---- keep-patients-with-fills
# Patients who were never dispensed antiretrovirals are dropped. Stata Step 6
# split the pharmacy file into about 147 pieces only because the merge ran out
# of memory; a join does not need that.
daily <- person_days |>
  semi_join(regimen_episodes, by = "studyid")

## ---- carry-regimen-forward
# Each regimen is placed on its start date and carried forward until the next
# one starts. Days before the first regimen in the study window have none.
daily <- daily |>
  left_join(regimen_episodes, by = c("studyid", "date" = "regimen_start")) |>
  mutate(new_regimen = !is.na(regimen_number)) |>
  arrange(studyid, date) |>
  group_by(studyid) |>
  fill(regimen, regimen_number, bid_regimen, .direction = "down") |>
  ungroup()

## ---- list-drugs-per-day
# Stata split the regimen name at "/" into CurrentDrug1Name, CurrentDrug2Name ...
# Here each drug is a row, numbered by its position in the regimen name.
daily_drugs <- daily |>
  filter(!is.na(regimen)) |>
  select(studyid, date, regimen_number, regimen) |>
  mutate(drug_name = regimen) |>
  separate_longer_delim(drug_name, delim = "/") |>
  group_by(studyid, date) |>
  mutate(drug_position = row_number()) |>
  ungroup()

## ---- mark-dispense-days
# A drug in the current regimen that was filled that day counts as 30 pills.
dispensed_drugs <- fills |>
  distinct(studyid, date = dispense_date, drug_name = drugname) |>
  mutate(pills_dispensed = fill_size_pills)

daily_drugs <- daily_drugs |>
  left_join(dispensed_drugs, by = c("studyid", "date", "drug_name")) |>
  mutate(pills_dispensed = coalesce(pills_dispensed, 0))
