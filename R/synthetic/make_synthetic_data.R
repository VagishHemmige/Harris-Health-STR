# Purpose: make small fake versions of the six source files, with the same column
#   names and formats as the originals, so the R translation can run end to end.
# Needs: nothing (run from the project root). Produces: CSV files in
#   data-synthetic/ (ignored by Git). Every value is random; no real patient is
#   represented. Not part of the definitive workflow.

library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(lubridate)

set.seed(20180813)
out_dir <- "data-synthetic"
dir.create(out_dir, showWarnings = FALSE)
n_patients <- 400

## Regimens and the pharmacy descriptions their drugs are filled under
regimen_drugs <- list(
  "Atripla" = c(Atripla = "ATRIPLA TAB"),
  "Complera" = c(Complera = "COMPLERA 200-25-300 TAB"),
  "Norvir/Prezista/Truvada" = c(Norvir = "NORVIR 100MG TAB", Prezista = "PREZISTA 400MG TAB",
                                Truvada = "TRUVADA TAB"),
  "Norvir/Reyataz/Truvada" = c(Norvir = "NORVIR 100MG TAB", Reyataz = "REYATAZ 300MG CAP",
                               Truvada = "TRUVADA TAB"),
  "Isentress/Truvada" = c(Isentress = "ISENTRESS 400MG TAB", Truvada = "TRUVADA TAB"),
  "Kaletra/Truvada" = c(Kaletra = "KALETRA 200-50MG TAB", Truvada = "TRUVADA TAB")
)
start_probs <- c(0.45, 0.05, 0.15, 0.20, 0.10, 0.05)

fmt <- function(d) format(d, "%m/%d/%Y")

## Patients
patients <- tibble(
  studyid = sample(1:3000, n_patients),
  art_start = ymd("2007-11-01") + sample(0:1550, n_patients, replace = TRUE),
  start_regimen = sample(names(regimen_drugs), n_patients, replace = TRUE, prob = start_probs),
  adherence = rbeta(n_patients, 6, 2),
  months_in_care = rgeom(n_patients, 0.03) + 1
) |>
  mutate(adherence = if_else(start_regimen %in% c("Atripla", "Complera"),
                             pmin(adherence + 0.05, 0.99), adherence))

## Pharmacy fills: roughly monthly, later when adherence is poor; some switch
## regimen; occasionally one drug of a multi-drug regimen is picked up a few
## days late, which is what the manual corrections fixed.
make_fills <- function(studyid, art_start, start_regimen, adherence, months_in_care) {
  regimen <- start_regimen
  fill_date <- art_start
  rows <- list()
  for (month in seq_len(months_in_care)) {
    drugs <- regimen_drugs[[regimen]]
    late <- length(drugs) > 1 && runif(1) < 0.04
    for (drug in names(drugs)) {
      offset <- if (late && drug == names(drugs)[1]) sample(2:5, 1) else 0
      rows[[length(rows) + 1]] <- tibble(studyid = studyid, medtransdate = fmt(fill_date + offset),
                                         drugname = drug, cdmdescription = unname(drugs[drug]))
    }
    fill_date <- fill_date + round(30 / adherence) + sample(-3:3, 1)
    if (runif(1) < 0.012) regimen <- sample(setdiff(names(regimen_drugs), regimen), 1)
  }
  bind_rows(rows)
}

fills <- pmap(patients |> select(studyid, art_start, start_regimen, adherence, months_in_care),
              make_fills) |>
  bind_rows() |>
  mutate(cdmcode = 1000 + as.integer(factor(cdmdescription)),
         cdpdrugcode = cdmcode + 50000,
         drugconstituents = drugname)

# Early Complera recorded as Truvada for a few patients
complera_ids <- patients |> filter(start_regimen == "Complera") |> slice_head(n = 3) |> pull(studyid)
fills <- fills |>
  mutate(drugname = if_else(studyid %in% complera_ids & runif(n()) < 0.5, "Truvada", drugname))

write_csv(fills, file.path(out_dir, "Excel Antiretrovirals_Taken_DeID.csv"))

## A made-up example of the manual corrections file
corrections <- tibble(
  studyid = complera_ids,
  first_date = as.Date(NA),
  last_date = as.Date(NA),
  regimen = "Complera"
)
write_csv(corrections, file.path(out_dir, "regimen_corrections.csv"), na = "")

## Labs every 2-5 months while in care, starting a few weeks before ART
make_labs <- function(studyid, art_start, adherence, months_in_care) {
  last_day <- art_start + 30 * months_in_care
  dates <- art_start - sample(5:60, 1)
  while (max(dates) < last_day) dates <- c(dates, max(dates) + sample(60:150, 1))
  baseline_vl <- round(10^rnorm(1, 4.8, 0.7))
  suppressed <- runif(length(dates)) < adherence & seq_along(dates) > 1
  tibble(studyid = studyid, testdate = fmt(dates),
         vl = if_else(suppressed, sample(c(20, 48, 75), length(dates), replace = TRUE),
                      round(baseline_vl * runif(length(dates), 0.01, 1.2))),
         cd4 = round(pmax(5, rnorm(1, 220, 150) + 15 * seq_along(dates) +
                            rnorm(length(dates), 0, 40))))
}

labs <- pmap(patients |> select(studyid, art_start, adherence, months_in_care), make_labs) |>
  bind_rows()

write_csv(labs |> transmute(studyid, testdate, testtype = "CD4", resultnumeric = cd4),
          file.path(out_dir, "Excel CD_4_DeID.csv"))
write_csv(labs |> transmute(studyid, testdate, testtype = "VL",
                            result = as.character(vl), resultnumeric = vl),
          file.path(out_dir, "Excel VL_DeID.csv"))

## Demographics, with a few lower-case codes as in the original extract
demographics <- patients |>
  transmute(
    studyid,
    age = sample(18:70, n_patients, replace = TRUE),
    gender = sample(c("M", "F", "m", "f"), n_patients, replace = TRUE, prob = c(0.68, 0.27, 0.03, 0.02)),
    ethnicity = sample(c("B", "H", "W", "b", "h"), n_patients, replace = TRUE,
                       prob = c(0.57, 0.29, 0.08, 0.03, 0.03)),
    primaryriskfactor = sample(c("MSM", "HET", "IDU", "MSM&IDU"), n_patients, replace = TRUE,
                               prob = c(0.45, 0.45, 0.07, 0.03)),
    hepc = rbinom(n_patients, 1, 0.1),
    intake_date = fmt(art_start - sample(10:120, n_patients, replace = TRUE)),
    first_undetect_date = "",
    undetectable = 0
  )
write_csv(demographics, file.path(out_dir, "Excel Cohort_DeID.csv"))

## Insurance and prior care (a few missing)
insurance <- patients |>
  transmute(
    studyid,
    insurancestatus = sample(c("Insured", "Other", "Uninsured", NA), n_patients, replace = TRUE,
                             prob = c(0.12, 0.05, 0.8, 0.03)),
    prevcareelsewhere = rbinom(n_patients, 1, 0.1)
  )
write_csv(insurance, file.path(out_dir, "ElementsAtIntake_DeID.csv"), na = "")

## Psychiatry visits for about a fifth of patients
psych <- patients |>
  slice_sample(prop = 0.2) |>
  transmute(studyid, psychvisitdate = fmt(art_start + sample(-200:400, n(), replace = TRUE)))
write_csv(psych, file.path(out_dir, "PsychVisits_DeID.csv"))
