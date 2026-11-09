# Purpose: read the CD4 and viral load results and the patient-level baseline
#   information: demographics, insurance, prior care and psychiatry visits
#   (Stata Steps 2, 3, 4, 4B and 4C).
# Needs: source_files (setup.R); read_source_csv() (functions.R).
# Produces: cd4 and viral_load (one row per test) and baseline (one row per patient).

## ---- read-cd4
cd4 <- read_source_csv(data_dir, source_files[["cd4"]]) |>
  transmute(studyid, lab_date = mdy(testdate), cd4 = resultnumeric)

## ---- read-viral-load
viral_load <- read_source_csv(data_dir, source_files[["viral_load"]]) |>
  transmute(studyid, lab_date = mdy(testdate), vl = resultnumeric)

## ---- read-demographics
# Lower-case codes are corrected, and indicators are made for Black and Hispanic
# ethnicity, injection drug use and men who have sex with men.
demographics <- read_source_csv(data_dir, source_files[["demographics"]]) |>
  mutate(
    gender = if_else(gender %in% c("f", "m"), str_to_upper(gender), gender),
    ethnicity = if_else(ethnicity %in% c("b", "h"), str_to_upper(ethnicity), ethnicity),
    male = gender == "M",  # Stata entered Gender (F = 1, M = 2) as a number: the same if only F and M occur
    black = ethnicity == "B",
    hispanic = ethnicity == "H",
    idu = primaryriskfactor %in% c("IDU", "MSM&IDU"),
    msm = primaryriskfactor %in% c("MSM", "MSM&IDU")
  ) |>
  select(studyid, age, gender, male, ethnicity, black, hispanic,
         primaryriskfactor, idu, msm, hepc)

## ---- read-insurance
insurance <- read_source_csv(data_dir, source_files[["insurance"]]) |>
  transmute(studyid, insurance_status = insurancestatus,
            prior_care_elsewhere = prevcareelsewhere)

# Stata's encode numbered the categories found in the whole file, in character
# code order. The propensity model uses the third (see 06_cohort.R).
insurance_categories <- str_sort(unique(na.omit(insurance$insurance_status)), locale = "C")

## ---- read-psych-visits
# The analysis uses only whether a patient ever had a psychiatry visit date.
psych_visits <- read_source_csv(data_dir, source_files[["psych_visits"]]) |>
  mutate(psych_date = mdy(psychvisitdate)) |>
  group_by(studyid) |>
  summarise(had_psych_visit = any(!is.na(psych_date)), .groups = "drop")

## ---- combine-baseline
# Stata merged these files one to one and kept patients found in any of them,
# including patients with lab results but no demographic record.
baseline <- demographics |>
  full_join(distinct(cd4, studyid), by = "studyid") |>
  full_join(distinct(viral_load, studyid), by = "studyid") |>
  full_join(insurance, by = "studyid") |>
  full_join(psych_visits, by = "studyid") |>
  mutate(had_psych_visit = coalesce(had_psych_visit, FALSE))
