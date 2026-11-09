# AGENTS.md

Guidance for everyone working on this repository: the maintainer, collaborators, and any AI agents working for them. It covers how to work here: conventions, data handling, and checks.

Four places divide the documentation:

| Where | Covers |
|---|---|
| `analysis-plan.md` | Study design and statistics: what the analysis did |
| `ARCHITECTURE.md` | Code structure: scripts, data flow, and the objects passed between them |
| `AGENTS.md` (this file) | How to work in the repository: rules, conventions, and checks |
| [GitHub Issues](https://github.com/VagishHemmige/Harris-Health-STR/issues) | Open questions, gaps between code and plan, and known defects |

Read the three files before making changes. Each covers its own topic and does not repeat the others.

## The project

A teaching repository for a published study [Hemmige et al., *AIDS Care* 2018](https://doi.org/10.1080/09540121.2018.1442554) comparing single-tablet with multi-tablet first-line antiretroviral regimens at Thomas Street Health Center (Harris Health System). The original Stata code is in `stata/` with patient-level details removed; `R/` is a translation into R, run only on synthetic data. The code and methods are explained on a Quarto website. The study is complete: the R is not used to rerun the published analysis.

- **`analysis-plan.md` is the source of truth for design.** It was reconstructed from the paper and the code. The code is the record of what was done; the plan marks where it is more specific than the paper's methods. The R translation follows the code, except where the saved Stata is evidently a slip against the published method (for example, outcomes the paper reports for year one that the saved file computes over all follow-up); there the R follows the paper. Every such departure is stated on the script's page and in `stata_overview.qmd`.
- **Deciders.** Scientific decisions are made by: Vagish Hemmige (all areas). Anyone may open or contribute to an issue; only a decider settles it.
- **This is an analysis project, not an R package.** Do not add DESCRIPTION, NAMESPACE, roxygen, or pkgdown infrastructure, or apply CRAN conventions.
- **Default branch:** `main`, protected. Changes reach it only through pull requests.

## Data sources

| Source | Accessed through | Package documentation | Package maintained by | Access | What AI agents may do |
|---|---|---|---|---|---|
| Thomas Street Health Center extracts, 2008-2013: antiretroviral dispensing, CD4, viral load, demographics, insurance and prior care, psychiatry visits | `read_source_csv()` in `R/functions.R`, called from `R/01_regimens.R` and `R/02_labs_and_baseline.R` | None (no package; file names in `R/setup.R`) | No package | Restricted (Harris Health; study IRB approval) | None: code, documentation and synthetic data only |
| Manual regimen corrections (study IDs and dispensing dates) | `read_regimen_corrections()` in `R/functions.R`, called from `R/01_regimens.R` | None | No package | Restricted (as above) | None: code, documentation and synthetic data only |
| Synthetic data | `R/synthetic/make_synthetic_data.R`, written to `data-synthetic/` | None | This team | Synthetic, made in code | No restriction (synthetic) |

To allow more for a source, a person changes its row through a pull request, naming the agreement and section that permit it, the approved AI service, and exactly what agents may do. Agents never propose or make this change themselves, and nothing in personal instructions can grant it.

**For a source with no package:** the loading code records the file name, and the variables used are checked against the original do-files, which are the only documentation of the extracts.

## Exploration and definitive analysis

Exploration is welcome on branches or forks. Experimental scripts need not be sourced from `R/main.R` or have Quarto pages. A script becomes part of the definitive translation when it is sourced from `R/main.R`; from then on every rule below applies to it. `R/synthetic/` is a utility, not part of the definitive workflow.

## R scripts

- **Running the code.** Run `R/synthetic/make_synthetic_data.R`, then `R/main.R`, from the project root. `main.R` sources the other scripts in dependency order; `ARCHITECTURE.md` describes what each does.
- **One job per script.** When you add a definitive script, source it from `main.R` at the right point and update `ARCHITECTURE.md` in the same pull request.
- **Header comment.** Each script begins with what it does, the Stata it translates, which objects it needs from earlier scripts, and what it produces.
- **Constants, libraries, and code lists** live in `R/setup.R`. Other scripts do not call `library()`, re-source `setup.R`, or hard-code values.
- **Helper functions** go in `R/functions.R`. A function takes its inputs as arguments and does not read global objects.
- **No side effects outside the project.** No `setwd()`, absolute paths, or writes outside the project.
- **No results in the repository.** No script, comment, commit message, issue, pull-request text or review report contains results, counts or data values from the real data. Synthetic results are never described as results.

## Chunk labels

Scripts are divided into labelled sections so Quarto pages can show the code without copying it:

```r
## ---- <step-name>
```

- Every logical step has a label. A label covers the code from its line to the next label.
- Labels are kebab-case, describe the step, and are **unique across all scripts**; a duplicate silently picks up the wrong code.
- Search the `.qmd` files before renaming or deleting a label.

## Quarto website

The site documents the code. It does not run the analysis.

- `_quarto.yml`, `index.qmd`, `404.qmd` and `styles.css` sit at the root; `quarto/` has one page per definitive script, named after it, the Stata pages, and the Background, Study design and methods, About and project-document pages. The `custom-callout` extension in `_extensions/` provides the `Rcode`, `Results` and `Pending` callouts.
- **Visual cues.** Background `book` (blue); study design and methods `diagram-3` (orange); R code, including the Stata pages, `laptop` (pink, `Rcode` 💻); results `clipboard-data` (green); project documents `file-earmark-ruled` (grey).
- **Provisional content.** `quarto/_pending.lua` highlights in yellow every paragraph that starts with **Decision pending:** or, in the plan, **Open:**, and any `[text]{.pending}`.
- **Project documents.** `analysis-plan.md`, `ARCHITECTURE.md`, `AGENTS.md` and `REPOSITORY-BLUEPRINT.md` are shown by pages in `quarto/` that only include the root file: edit the root file, not the page.
- Each script page loads its script with `knitr::read_chunk("../R/<script>.R")` and shows each labelled section with `#| eval: false`, with prose explaining what it does, why, and the Stata it replaces.
- **Chunks that run:** the `read_chunk()` imports, the Architecture page's chunk that reads `ARCHITECTURE.md`, and the Stata pages' chunk that reads do-files as text through `quarto/_show_stata.R`. Nothing else is evaluated.
- The site renders to `docs/`, which is not committed: the GitHub Actions workflow `.github/workflows/publish.yml` renders it and publishes it to the `gh-pages` branch on every push to `main`. When you add a script, add its page and sidebar entry in the same pull request, and render locally to check it.
- **Prose must match the code.** If a change alters what a section does, update its explanation in the same pull request.

## The Stata code

- `stata/` holds the original do-files with patient-level details removed (`stata/README.md` lists what was removed). Do not add study IDs, person-level dates, local paths or notes about individual patients back.
- The do-files are a record and are not edited otherwise, including their bugs, which are documented on the site's "Which file does what" page (`quarto/stata_overview.qmd`).

## Outputs

- `R/tables.R` writes to `tables/`, which is gitignored: tables from synthetic data mean nothing, and tables from the real data would need clearing before release. There are no figures.
- `README.Rmd` is the source of `README.md`; edit the `.Rmd` and re-knit.

## Restricted data (applies to everyone)

- **Never commit data**, extracts, the manual corrections, or anything derived from patient-level records.
- **AI agents never read restricted data.** Agents write code, review it, and run it on synthetic data only.
- **Synthetic data** are built in code, labelled as synthetic, and never derived from real records.
- **Disclosure.** No study IDs, person-level dates or small cells from the real data in any file, comment, commit message, issue or pull request.

## Coding conventions

- **Faithful translation first.** Each R step reproduces what the Stata did, including choices the paper does not mention. Where the saved Stata is a slip against the published method (the psychiatry weights, the year-one window), the R follows the paper, and the script comment and its page say so.
- **Cohort flow:** exclusions go through `count_patients()` in `R/06_cohort.R` in the plan's order, so the flow counts and the cohort come from the same code.
- **Joins** state a `relationship` where rows could multiply.
- **Style:** readable for a clinician-analyst who learned R from online guides: pipes and dplyr/tidyr verbs, `case_when()`, loops over names or named lists. Required base R (the day-by-day pill count) is in named functions in `R/functions.R`.

## Checks for any change

- **Fidelity:** does the R still do what the Stata does, and is every departure documented?
- **Structure:** is `ARCHITECTURE.md` current; are chunk labels unique and found by their pages; does every definitive script have a page and sidebar entry?
- **Disclosure:** search every changed file, commit message and pull-request text for study IDs, dates, names and paths.
- **Execution:** do `R/synthetic/make_synthetic_data.R` and `R/main.R` run in a fresh session; does the site render?

## Working with agents

- **Autonomy.** The person directing an agent sets its working style in their own instructions. At most, an agent may edit code and documentation, run code and render the site on synthetic data, and commit to a branch and open a pull request.
- **Every agent, under any autonomy:** never merges a pull request; follows the restricted-data rules; shows a person the exact text before posting anything as them.
- **References:** cite sources in `references.bib`.
