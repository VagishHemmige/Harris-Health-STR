# Site helper: shows the Stata do-files in sections and links each section to
# the R steps that replace it, and each R step back to its Stata. Both sides
# come from quarto/stata_map.csv (do-file, line range, title, R chunk labels).
# It reads code and text only: no data, no analysis.

stata_map <- utils::read.csv("stata_map.csv", stringsAsFactors = FALSE,
                             na.strings = character())
stata_repo <- "https://github.com/VagishHemmige/Harris-Health-STR/blob/main/stata/"

# The page showing each do-file's sections.
stata_page <- function(file_name) {
  if (file_name == "Do Final Analysis.do") "stata_final_analysis.qmd" else "stata_data_build.qmd"
}

# Which R page shows each chunk label, found from the pages' `#| label:` lines.
label_pages <- function() {
  pages <- list.files(".", pattern = "\\.qmd$")
  found <- character()
  for (page in pages) {
    lines <- readLines(page, warn = FALSE, encoding = "UTF-8")
    labels <- sub("^#\\| label: *", "", grep("^#\\| label:", lines, value = TRUE))
    found[labels] <- page
  }
  found
}

do_lines <- function(file_name) {
  readLines(file.path("..", "stata", file_name), warn = FALSE, encoding = "UTF-8")
}

stata_block <- function(code, first_line) {
  paste0("```{.stata .number-lines startFrom=\"", first_line, "\"}\n",
         paste(code, collapse = "\n"), "\n```\n")
}

# On a Stata page: one do-file, section by section, each linked to its R steps.
show_stata_file <- function(file_name, fold_over = 25) {
  lines <- do_lines(file_name)
  sections <- stata_map[stata_map$file == file_name, ]
  pages <- label_pages()
  cat("\n\n## ", file_name, "\n\n", sep = "")
  cat("[Whole file on GitHub](", stata_repo, utils::URLencode(file_name), ") · ",
      length(lines), " lines\n\n", sep = "")
  for (row in seq_len(nrow(sections))) {
    section <- sections[row, ]
    code <- lines[section$from:section$to]
    cat("### Lines ", section$from, "-", section$to, ": ", section$title,
        " {#", section$id, "}\n\n", sep = "")
    labels <- strsplit(section$r_labels, ";")[[1]]
    labels <- labels[labels != ""]
    if (length(labels) > 0) {
      links <- paste0("[`", labels, "`](", pages[labels], "#r-", labels, ")")
      cat("**In R:** ", paste(links, collapse = ", "), "\n\n", sep = "")
    } else {
      cat("**Not translated:** ", section$note, "\n\n", sep = "")
    }
    if (length(code) > fold_over) {
      cat("<details><summary>Show these ", length(code), " lines</summary>\n\n", sep = "")
      cat(stata_block(code, section$from))
      cat("\n</details>\n\n")
    } else {
      cat(stata_block(code, section$from), "\n")
    }
  }
}

# On an R page, after a chunk: the Stata it replaces, folded, with a link to
# that section in context, after the links to helper functions
# (_function_links.R). Also gives the R step an anchor (#r-<label>) for the
# links from the Stata pages.
stata_for <- function(label) {
  cat("\n\n::: {#r-", label, " .stata-crosslink}\n\n", sep = "")
  function_links(label)
  has_label <- grepl(paste0("(^|;)", label, "(;|$)"), stata_map$r_labels)
  sections <- stata_map[has_label, ]
  for (row in seq_len(nrow(sections))) {
    section <- sections[row, ]
    code <- do_lines(section$file)[section$from:section$to]
    cat("<details><summary>Stata: <code>", section$file, "</code>, lines ",
        section$from, "-", section$to, " (", section$title, ")</summary>\n\n", sep = "")
    cat("[See it in context](", stata_page(section$file), "#", section$id, ")\n\n", sep = "")
    cat(stata_block(code, section$from))
    cat("\n</details>\n\n")
  }
  cat(":::\n\n")
}

source("_function_links.R")
