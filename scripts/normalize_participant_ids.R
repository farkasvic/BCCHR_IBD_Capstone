#!/usr/bin/env Rscript
# Build an audit of participant ID strings across key tables and write a
# normalized copy of mycobiome sample meta for easier merging.
#
# Usage (from project root):
#   Rscript scripts/normalize_participant_ids.R

suppressPackageStartupMessages({
  library(readr)
  library(readxl)
  library(dplyr)
})

root <- "."
src_path <- file.path(root, "src", "participant_id.R")
if (!file.exists(src_path)) {
  stop("Run from project root: missing ", src_path)
}
source(src_path)

intermediate_dir <- file.path(root, "data", "intermediate")
dir.create(intermediate_dir, showWarnings = FALSE, recursive = TRUE)

audit_chunk <- function(source, col_name, values) {
  u <- sort(unique(na.omit(trimws(as.character(values)))))
  u <- u[nzchar(u)]
  if (length(u) == 0L) {
    return(
      data.frame(
        source = character(),
        column = character(),
        raw = character(),
        normalized = character(),
        stringsAsFactors = FALSE
      )
    )
  }
  data.frame(
    source = source,
    column = col_name,
    raw = u,
    normalized = normalize_participant_id(u),
    stringsAsFactors = FALSE
  )
}

chunks <- list()

meta_path <- file.path(root, "data/raw/OPT_MBI sample IDs meta.xlsx")
if (file.exists(meta_path)) {
  meta <- read_excel(meta_path)
  chunks[[length(chunks) + 1L]] <- audit_chunk(
    "raw_meta", "Participant ID", meta[["Participant ID"]]
  )
  meta$`Participant ID` <- normalize_participant_id(meta$`Participant ID`)
  out_meta <- file.path(
    intermediate_dir,
    "OPT_MBI_sample_IDs_meta_participant_id_normalized.csv"
  )
  write_csv(meta, out_meta)
  message("Wrote normalized meta: ", out_meta)
}

chars_path <- file.path(root, "data/processed/cleaned_characteristics.csv")
if (file.exists(chars_path)) {
  ch <- read_csv(chars_path, show_col_types = FALSE)
  if ("participant_id" %in% names(ch)) {
    chunks[[length(chunks) + 1L]] <- audit_chunk(
      "cleaned_characteristics", "participant_id", ch$participant_id
    )
  }
}

diet_path <- file.path(root, "data/processed/dietary_cleaned.xlsx")
if (file.exists(diet_path)) {
  di <- read_excel(diet_path, sheet = "Data")
  col <- "Participant ID (ESHA ID)"
  if (col %in% names(di)) {
    chunks[[length(chunks) + 1L]] <- audit_chunk(
      "dietary_cleaned", col, di[[col]]
    )
  }
}

chunks <- chunks[vapply(chunks, nrow, integer(1)) > 0L]
if (length(chunks) == 0L) {
  stop("No inputs found to audit (check data paths).")
}

audit <- bind_rows(chunks) |>
  distinct(source, column, raw, .keep_all = TRUE)

audit_path <- file.path(
  intermediate_dir,
  "participant_id_normalization_audit.csv"
)
write_csv(audit, audit_path)
message("Wrote audit: ", audit_path, " (", nrow(audit), " rows)")
