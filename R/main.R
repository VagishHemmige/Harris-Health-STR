# Purpose: run the R translation in dependency order, the counterpart of
#   stata/Do Main do file.do followed by stata/Do Final Analysis.do.
# Run from the project root in a fresh session. By default it reads the
# synthetic data made by R/synthetic/make_synthetic_data.R.

source("R/setup.R")
source("R/functions.R")

# Building the person-day data set (Stata Steps 0B-8)
source("R/01_regimens.R")
source("R/02_labs_and_baseline.R")
source("R/03_person_days.R")
source("R/04_daily_regimen.R")
source("R/05_adherence.R")

# The published analysis (Final Analysis.do)
source("R/06_cohort.R")
source("R/07_propensity.R")
source("R/08_outcomes.R")
source("R/09_sensitivity.R")

source("R/tables.R")
