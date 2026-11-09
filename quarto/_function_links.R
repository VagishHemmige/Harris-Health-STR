# Site helper: links each helper function on the Functions page to the R steps
# that call it, and each R step to the helper functions it calls. Both lists
# are found by reading the R scripts as text when the site is rendered, so they
# stay current as the code changes. It reads code only: no data, no analysis.
# Needs label_pages() from _stata_links.R.

# The chunk label of every line of a script, from its `## ---- label` lines.
chunk_of_lines <- function(lines) {
  starts <- grepl("^## ---- ", lines)
  labels <- sub("^## ---- *", "", lines)
  labels[!starts] <- NA
  current <- NA_character_
  for (i in seq_along(labels)) {
    if (!is.na(labels[i])) current <- labels[i] else labels[i] <- current
  }
  labels
}

# Each helper function's name, chunk label, and section on the Functions page.
helper_functions <- function() {
  lines <- readLines(file.path("..", "R", "functions.R"), warn = FALSE, encoding = "UTF-8")
  chunks <- chunk_of_lines(lines)
  defines <- grepl("^[A-Za-z_.][A-Za-z0-9_.]* *<- *function", lines)
  helpers <- data.frame(name = sub(" *<-.*", "", lines[defines]),
                        label = chunks[defines], stringsAsFactors = FALSE)

  # The section heading above each chunk on the Functions page gives its anchor.
  page <- readLines("functions.qmd", warn = FALSE, encoding = "UTF-8")
  heading <- NA_character_
  anchor <- character()
  for (line in page) {
    if (grepl("^## ", line)) heading <- sub("^## +", "", line)
    if (grepl("^#\\| label:", line)) {
      anchor[sub("^#\\| label: *", "", line)] <- heading
    }
  }
  slug <- function(text) gsub(" +", "-", gsub("[^a-z0-9 -]", "", tolower(text)))
  helpers$section <- slug(anchor[helpers$label])
  helpers
}

# Every call of a helper function from a labelled chunk of any script,
# including helpers that call other helpers.
helper_calls <- function(helpers = helper_functions()) {
  scripts <- list.files(file.path("..", "R"), pattern = "\\.R$", full.names = TRUE)
  calls <- list()
  for (script in scripts) {
    lines <- readLines(script, warn = FALSE, encoding = "UTF-8")
    lines_code <- sub("#.*$", "", lines)
    chunks <- chunk_of_lines(lines)
    for (fn in helpers$name) {
      pattern <- paste0("(^|[^A-Za-z0-9_.])", gsub(".", "\\.", fn, fixed = TRUE), "\\(")
      used <- grepl(pattern, lines_code) & !grepl(paste0("^", fn, " *<- *function"), lines)
      if (any(used & !is.na(chunks))) {
        calls[[length(calls) + 1]] <- data.frame(
          name = fn, label = unique(chunks[used & !is.na(chunks)]), stringsAsFactors = FALSE)
      }
    }
  }
  calls <- unique(do.call(rbind, calls))
  calls[calls$label != helpers$label[match(calls$name, helpers$name)], ]
}

page_title <- function(page) {
  lines <- readLines(page, warn = FALSE, encoding = "UTF-8", n = 10)
  title <- grep("^title:", lines, value = TRUE)[1]
  gsub("^title: *\"?|\"$", "", title)
}

# Printed under a chunk: on the Functions page, where each function defined in
# the chunk is used; on a script page, the helper functions the chunk calls.
function_links <- function(label) {
  helpers <- helper_functions()
  calls <- helper_calls(helpers)
  defined <- helpers[helpers$label %in% label, ]
  if (nrow(defined) > 0) {
    pages <- label_pages()
    for (fn in defined$name) {
      uses <- calls[calls$name == fn, ]
      if (nrow(uses) == 0) next
      where <- pages[uses$label]
      titles <- vapply(where, page_title, character(1))
      steps <- gsub("-", " ", uses$label)
      links <- paste0("[", titles, ": ", steps, "](", where, "#r-", uses$label, ")")
      cat("**`", fn, "()` is used in:** ", paste(links, collapse = "; "), "\n\n", sep = "")
    }
  } else {
    used <- calls[calls$label == label, ]
    if (nrow(used) == 0) return(invisible())
    sections <- helpers$section[match(used$name, helpers$name)]
    links <- paste0("[`", used$name, "()`](functions.qmd#", sections, ")")
    cat("**Helper functions used here:** ", paste(links, collapse = ", "), "\n\n", sep = "")
  }
}
