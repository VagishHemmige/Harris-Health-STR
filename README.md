
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![Status](https://img.shields.io/badge/status-teaching_material-blue)](#)
[![Published](https://img.shields.io/badge/published-AIDS_Care_2018-green)](https://doi.org/10.1080/09540121.2018.1442554)
[![Data](https://img.shields.io/badge/data-synthetic_only-lightgrey)](#)
<!-- badges: end -->

# Single-tablet HIV regimens at Thomas Street Health Center: Stata to R

Teaching material for Hemmige V, Flash CA, Carter J, Giordano TP, Zerai
T. Single tablet HIV regimens facilitate virologic suppression and
retention in care among treatment naive patients. *AIDS Care.*
2018;30(8):1017-1024.
[doi:10.1080/09540121.2018.1442554](https://doi.org/10.1080/09540121.2018.1442554).

The study compared patients starting a single-tablet regimen with those
starting three pills once a day, using pharmacy fills and laboratory
results from a Harris Health System HIV clinic. This repository holds
the original Stata code, with patient-level details removed, and a
step-by-step translation into R.

The website, which explains every step and shows the R next to the Stata
it replaces, is at: <https://vagishhemmige.github.io/Harris-Health-STR/>

## Documentation

- [`analysis-plan.md`](analysis-plan.md): what the analysis did, and
  where the code differs from the paper
- [`ARCHITECTURE.md`](ARCHITECTURE.md): how the R code is organized
- [`AGENTS.md`](AGENTS.md): how to work in this repository
- [`stata/`](stata/): the original do-files and what was removed from
  them

## Running the R code

The clinic data are not public and are not here. The R runs on synthetic
data:

``` r
source("R/synthetic/make_synthetic_data.R")  # writes fake inputs to data-synthetic/
source("R/main.R")                           # runs the translation
```

Packages: dplyr, tidyr, readr, stringr, lubridate, purrr, broom and
survey. Results from synthetic data are meaningless and are not results
of the study.
