# Original Stata code

The do-files behind Hemmige et al., *AIDS Care* 2018;30(8):1017-1024 ([doi:10.1080/09540121.2018.1442554](https://doi.org/10.1080/09540121.2018.1442554)), written 2014-2017 in Stata 12. `Do Main do file.do` runs the data build (Steps 0B-8), and `Do Final Analysis.do` is the published analysis, run from the data set they make. Earlier versions, earlier analyses and scratch files are not included; the main do-file still names some of them. How the files fit together is explained on the website's [Which file does what](https://vagishhemmige.github.io/Harris-Health-STR/quarto/stata_overview.html) page.

## What was removed for privacy

These are copies of the originals with patient-level details removed. Nothing else was changed, including mistakes.

| File | Removed |
|---|---|
| Do Step 0B Current Regimen.do | 576 manual regimen corrections, each naming a study ID (396 also with a dispensing date or date range); 43 comment lines about individual patients among the corrections and 24 more in the checking section that follows; a person's name in a comment |
| Do Step 1A Pharmacy Part 1.do | 5 corrections naming a study ID and dates, and a comment listing the IDs; the largest number of drugs dispensed to one patient, from a comment |
| Do Step 6 Tokenize Pharmacy.do, Do Step 7 Merge Pharmacy.do | The same number, from a comment each |
| Do Main do file.do | A local folder path; a deliberate stop line |
| Do Final Analysis.do | A deliberate stop line |

Each block of removed corrections is replaced by a comment giving the number of lines and their form; each removed note by a one-line comment; the path by `"<your analysis folder>"`; and stop lines by a comment. Aggregate counts typed into the code are kept, except one that described a single patient, which was removed from the comments without replacement.

The do-files read de-identified CSV extracts that are not in this repository.
