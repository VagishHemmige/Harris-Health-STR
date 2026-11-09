# Purpose: work out each patient's antiretroviral regimen over time from pharmacy
#   fills (Stata Step 0B, with the drug-name fixes Step 1A repeats).
# Needs: source_files, drug_name_fixes, bid_descriptions, regimen_corrections_file
#   (setup.R); read_source_csv(), read_regimen_corrections(), make_regimen_name(),
#   apply_regimen_corrections() (functions.R).
# Produces: fills (one row per drug dispensed) and regimen_episodes (one row per
#   regimen a patient started, with its start date and whether it is twice daily).

## ---- read-fills
fills_raw <- read_source_csv(data_dir, source_files[["dispensing"]])

## ---- fix-drug-names
fills <- fills_raw |>
  left_join(drug_name_fixes, by = "cdmdescription") |>
  mutate(
    drugname = coalesce(fixed_drugname, drugname),
    dispense_date = mdy(medtransdate),
    bid_drug = cdmdescription %in% bid_descriptions
  ) |>
  filter(!is.na(drugname), drugname != "") |>
  select(studyid, dispense_date, drugname, cdmdescription, bid_drug)

## ---- name-regimen-per-fill-date
dispense_regimens <- fills |>
  group_by(studyid, dispense_date) |>
  summarise(regimen = make_regimen_name(drugname), .groups = "drop")

## ---- apply-manual-corrections
regimen_corrections <- read_regimen_corrections(regimen_corrections_file)
dispense_regimens <- apply_regimen_corrections(dispense_regimens, regimen_corrections)

## ---- recode-early-complera
# When Complera was new, some fills were recorded as Truvada. Once a fill date's
# regimen is Complera, a Truvada fill on that date is recoded as Complera.
fills <- fills |>
  left_join(dispense_regimens, by = c("studyid", "dispense_date")) |>
  mutate(drugname = if_else(drugname == "Truvada" & regimen == "Complera",
                            "Complera", drugname))

## ---- check-drugs-within-regimens
# Stata cross-tabulated drugs against regimens to find implausible pairs, then
# looked at the patients behind each. This is the same table.
regimen_drug_check <- fills |>
  count(regimen, drugname)

## ---- number-regimen-episodes
# A new regimen starts on any fill date whose regimen name differs from the
# previous fill date's. A regimen is twice daily if any fill in it is a
# twice-daily product.
regimen_episodes <- fills |>
  group_by(studyid, dispense_date, regimen) |>
  summarise(bid_dispense = any(bid_drug), .groups = "drop") |>
  arrange(studyid, dispense_date) |>
  group_by(studyid) |>
  mutate(
    new_regimen = regimen != lag(regimen, default = ""),
    regimen_number = cumsum(new_regimen)
  ) |>
  group_by(studyid, regimen_number) |>
  summarise(
    regimen = first(regimen),
    regimen_start = first(dispense_date),
    bid_regimen = any(bid_dispense),
    .groups = "drop"
  )
