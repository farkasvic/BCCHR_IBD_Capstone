# merge_files.R
# Merge clean characteristics and diet files to the mycobiome data

library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(here)

# ── Paths ────────────────────────────────────────────────────────────
# Set up directories
intermediate_dir <- here("data", "intermediate")
processed_dir    <- here("data", "processed")
dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)

# Meta Columns
meta_cols <- c(
  "Sample_ID", "Participant_ID", "Sample_type",
  "Study_group_new", "Fiber_restriction"
)

# ── Loaders ──────────────────────────────────────────────────────────

# Load the characteristics files
load_characteristics <- function(path) {
  df <- read_csv(path, show_col_types = FALSE)
  df$participant_id <- toupper(trimws(df$participant_id))
  df
}

# Load the dietary file
load_dietary <- function(path) {
  df <- read_excel(path)
  df$participant_id <- toupper(trimws(df[["Participant ID (ESHA ID)"]]))
  # Coerce any character columns that should be numeric (e.g. "--" for missing)
  df <- df |>
    mutate(across(
      where(is.character) & !any_of(c(
        "participant_id", "Participant ID (ESHA ID)", "Timepoint", "Day"
      )),
      \(x) suppressWarnings(as.numeric(x))
    ))
  df
}

# ── Helpers ──────────────────────────────────────────────────────────

# Pivot one taxa level from long to wide, prefixing taxon column names.
# Currently, taxa levels are imported as a list
# e.g. "Ascomycota" → "p__Ascomycota" with one row per Sample_ID.
pivot_taxa <- function(taxa_long, prefix) {
  taxon_col <- setdiff(names(taxa_long), c(meta_cols, "Value"))
  taxa_long |>
    mutate(
      across(all_of(taxon_col), \(x) paste0(prefix, x)),
      Participant_ID = toupper(trimws(Participant_ID))
    ) |>
    pivot_wider(
      id_cols     = all_of(meta_cols),
      names_from  = all_of(taxon_col),
      values_from = Value,
      values_fill = 0
    )
}

# Aggregate dietary to one row per participant (mean numeric cols across days).
aggregate_dietary <- function(dietary) {
  dietary |>
    group_by(participant_id) |>
    summarise(
      across(where(is.numeric), \(x) mean(x, na.rm = TRUE)),
      .groups = "drop"
    )
}


# ── Main ──────────────────────────────────────────────────────────────

# Defensive programming
required_files <- c(
  taxa            = file.path(intermediate_dir, "taxa_long_list.rds"),
  characteristics = file.path(processed_dir,   "cleaned_characteristics.csv"),
  dietary         = file.path(processed_dir,   "dietary_cleaned.xlsx")
)
missing <- required_files[!file.exists(required_files)]
if (length(missing)) {
  stop(
    "Missing input files:\n",
    paste(names(missing), missing, sep = " → ", collapse = "\n")
  )
}


df <- read_excel(required_files["dietary"])


# Load 
taxa_list   <- readRDS(required_files["taxa"])
chars       <- load_characteristics(required_files["characteristics"])
dietary_agg <- aggregate_dietary(load_dietary(required_files["dietary"]))

# Pivot each taxa level to wide and left-join on meta columns so no
# samples are dropped if a level is missing a taxon.
taxa_wide <- pivot_taxa(taxa_list[["phylum"]], "p__") |>
  left_join(pivot_taxa(taxa_list[["genus"]],   "g__"), by = meta_cols) |>
  left_join(pivot_taxa(taxa_list[["species"]], "s__"), by = meta_cols)

# ── Match diagnostics (mycobiome as limiting dataset) ─────────────────────

chars$participant_id <- gsub("_(\\d)$", "_0\\1", chars$participant_id)

myco_ids <- unique(taxa_wide$Participant_ID)
char_ids <- unique(chars$participant_id)
diet_ids <- unique(dietary_agg$participant_id)

report_match <- function(myco, other, label) {
  matched   <- intersect(myco, other)
  myco_only <- setdiff(myco, other)
  other_only <- setdiff(other, myco)
  message(
    label, " match:\n",
    "  matched:        ", length(matched),   " / ", length(myco), " mycobiome participants\n",
    "  missing in ", label, ": ",
    if (length(myco_only) == 0) "none"
    else paste(myco_only, collapse = ", "), "\n"
  )
}

report_match(myco_ids, char_ids, "characteristics")
report_match(myco_ids, diet_ids, "dietary")

# One wide table: taxa is the anchor — chars and dietary are left-joined so
# mycobiome samples are never dropped when other data is missing.
merged <- taxa_wide |>
  left_join(chars,       by = c("Participant_ID" = "participant_id")) |>
  left_join(dietary_agg, by = c("Participant_ID" = "participant_id"))

out_path <- file.path(processed_dir, "merged.csv")
write_csv(merged, out_path)
message(
  "Saved: ", out_path,
  " — ", nrow(merged), " rows x ", ncol(merged), " cols"
)
