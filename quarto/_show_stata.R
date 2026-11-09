# Site helper: prints a do-file from stata/ as a folded Stata code block.
# It reads code only, never data, and runs no analysis.
show_do_file <- function(file_name, open = FALSE) {
  lines <- readLines(file.path("..", "stata", file_name), warn = FALSE, encoding = "UTF-8")
  link <- paste0("https://github.com/VagishHemmige/Harris-Health-STR/blob/main/stata/",
                 utils::URLencode(file_name))
  cat("\n\n<details", if (open) " open", "><summary><code>", file_name,
      "</code> (", length(lines), " lines)</summary>\n\n", sep = "")
  cat("[View on GitHub](", link, ")\n\n", sep = "")
  cat("```stata\n")
  cat(lines, sep = "\n")
  cat("\n```\n\n</details>\n\n")
}
