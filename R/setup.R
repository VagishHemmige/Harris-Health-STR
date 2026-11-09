# Purpose: attach packages and define the paths and constants every script uses.
# Needs: nothing. Produces: attached packages, file locations and named constants.
# Teaching translation of the Stata code in stata/. It is not used to rerun the
# published analysis; R/synthetic/make_synthetic_data.R makes fake input files
# so the code can be run end to end.

## ---- load-packages
library(dplyr)      # data manipulation
library(tidyr)      # fill(), separate_longer_delim()
library(readr)      # reading the source CSV files
library(stringr)    # text: drug names and regimen names
library(lubridate)  # dates
library(broom)      # tidy model output
library(survey)     # weighted (IPW) logistic regression with robust standard errors

## ---- define-paths
# The original analysis read six de-identified CSV extracts. Here they are read
# from data_dir, which defaults to the synthetic copies made by
# R/synthetic/make_synthetic_data.R. No real data are in this repository.
data_dir <- Sys.getenv("STR_DATA_DIR", unset = "data-synthetic")

source_files <- c(
  dispensing   = "Excel Antiretrovirals_Taken_DeID.csv",
  cd4          = "Excel CD_4_DeID.csv",
  viral_load   = "Excel VL_DeID.csv",
  demographics = "Excel Cohort_DeID.csv",
  insurance    = "ElementsAtIntake_DeID.csv",
  psych_visits = "PsychVisits_DeID.csv"
)

# Manual per-patient regimen corrections (Stata Step 0B). The real ones are not
# published; the synthetic data folder holds a made-up example.
regimen_corrections_file <- file.path(data_dir, "regimen_corrections.csv")

tables_dir <- "tables"

## ---- define-study-window
# Stata Step 5 gives every patient one row per day for 2,192 days, starting at
# Stata date 17532 (1 January 2008).
study_start <- ymd("2008-01-01")
study_end   <- ymd("2013-12-31")

## ---- define-drug-lists
# Fills recorded as "Experimental" or "Other" whose pharmacy description shows
# the actual drug (Stata Steps 0B and 1A).
drug_name_fixes <- tribble(
  ~cdmdescription,                ~fixed_drugname,
  "H-23052 KALETRA 200/50MG TAB", "Kaletra",
  "H-23052 LOPINAVIR/RI",         "Kaletra",
  "H-23052 LAMIVUDINE 1",         "Epivir",
  "H-23052 LAMIVUDINE 300MG TAB", "Epivir",
  "HSC-070511 RALTEGRAV 400MG T", "Isentress",
  "COMPLERA 200-25-300 TAB",      "Complera"
)

# Pharmacy descriptions of products taken twice daily (Stata Step 0B). A regimen
# containing any of these is a twice-daily (BID) regimen.
bid_descriptions <- c(
  "KALETRA SOLN 400-100", "KALETRA      400-100", "ISENTRESS 400MG TAB",
  "INTELENCE 200MG TAB", "INTELENCE 100MG TAB", "HSC-090025 RALTEGRAV",
  "HSC-080661 RALTEGRAV", "HSC-080071 RALTEGRAV", "HSC-070511 RALTEGRAV",
  "H-23052 LOPINAVIR/RI", "H-23052 KALETRA 200/5", "DARUNAVIR 600MG TAB",
  "DARUNAVIR 300MG", "COMBIVIR 300-150 TAB", "H-23052 KALETRA 200/50MG TAB",
  "HSC-070511 RALTEGRAV 400MG T", "HSC-080661 RALTEGRAV 400MG T",
  "KALETRA      400-100 LIQ", "KALETRA 200-50MG TAB", "KALETRA SOLN 400-100 LIQ",
  "HSC-080071 RALTEGRAV 400MG T", "ZIDOVUDINE SYRUP 50MG/5ML SY",
  "ZIDOVUDINE 300MG TAB", "TRIZIVIR 300/150/300", "TRIZIVIR 300-300-150 TAB",
  "SELZENTRY 150MG TAB", "RITONAVIR-LOPINAVIR", "RETROVIR SYRUP 50MG/5ML SYR",
  "RETROVIR 50MG/5ML SYR", "RALTEGRAVIR 400MG", "PREZISTA 600MG TAB",
  "MARAVIROC 150 MG TAB", "LOPINAVIR/RITONAVIR", "LAMIVUDINE/ZIDOVUDIN",
  "LAMIVUDINE-ZIDOVUDIN TAB"
)

# Single-tablet regimens (STR).
single_tablet_regimens <- c("Stribild", "Atripla", "Complera")

# Starting regimens compared in the published analysis (Final Analysis.do):
# efavirenz/tenofovir/emtricitabine against ritonavir-boosted darunavir or
# atazanavir with tenofovir/emtricitabine.
manuscript_regimens <- c("Atripla", "Norvir/Prezista/Truvada", "Norvir/Reyataz/Truvada")

## ---- define-thresholds
fill_size_pills        <- 30    # every fill assumed to be 30 pills (30 days)
vl_suppression_main    <- 400   # copies/mL, assay limit in 2008
vl_suppression_later   <- 50    # copies/mL, sensitivity analysis for starts after 2008
lab_window_days        <- 90    # a viral load counts for 90 days either side
pdc_adherent           <- 0.8   # proportion of days covered counted as adherent
retention_min_gap_days <- 90    # HRSA retention: two viral loads more than 90 days apart
missed_fill_days       <- 90    # days without a fill used to flag outside pharmacies

## ---- define-categories
# Stata egen cut(), at(): each interval includes its lower limit, and values at
# or above the last limit are missing. cut(right = FALSE) does the same.
quarter_breaks <- c(0, 1, 92, 183, 274, 365)  # day 0, then four quarters of year one
age_breaks     <- c(0, 25, 35, 45, 55, 65, 100)
vl_breaks      <- c(0, 401, 1000, 10000, 100000, 1000000, 10000001)
cd4_breaks     <- c(0, 50, 100, 200, 500, 1000000)
