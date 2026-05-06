# 02_data_wrangling.R: Metadata joins, reshaping, NA handling, removals

# ---- Setup ----

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

source("src/mycobiome/00_functions.R")


# ---- Load Imported Data ----

data_list <- readRDS("./data/intermediate/data_list.rds")
meta_raw <- readRDS("./data/intermediate/meta_raw.rds")


# ---- Prepare Metadata ----

meta_data <- meta_raw |>
  rename(Participant_ID = `Participant ID`) |>
  select(
    Sample_ID, Participant_ID, Sample_type,
    Study_group_new, Fiber_restriction
  ) |>
  distinct()


# ---- Attach Metadata to Each Table ----

meta_cols <- names(meta_data)
for (name in names(data_list)) {
  df <- data_list[[name]]
  if ("Participant ID" %in% names(df)) {
    df <- df |> select(-`Participant ID`)
  }
  data_list[[name]] <- df |>
    left_join(meta_data, by = "Sample_ID") |>
    select(all_of(meta_cols), everything())
}


# ---- Convert Taxa Tables to Long Format ----

family_long <- make_taxa_long(data_list$family, "Family", meta_cols)
genus_long <- make_taxa_long(data_list$genus, "Genus", meta_cols)
species_long <- make_taxa_long(data_list$species, "Species", meta_cols)
phylum_long <- make_taxa_long(data_list$phylum, "Phylum", meta_cols)

# Store long taxa tables in one container
taxa_long_list <- list(
  family = family_long,
  genus = genus_long,
  species = species_long,
  phylum = phylum_long
)

# Store the relevant taxonomic column name for each table
tax_cols <- c(
  family = "Family",
  genus = "Genus",
  species = "Species",
  phylum = "Phylum"
)


# ---- Inspect Missing Taxa Values ----

# Count missing Values for each taxonomic level and calculate proportions
na_summary <- lapply(names(taxa_long_list), function(col) {
  df <- taxa_long_list[[col]]
  data.frame(
    level = col,
    n_na = sum(is.na(df$Value)),
    prop_na = mean(is.na(df$Value))
  )
}) |> bind_rows()

cat("\nNA value summary:\n")
print(na_summary)


# ---- Identify Samples to Remove for Unidentified Fungi ----

high_na_samples <- bind_rows(lapply(
  names(taxa_long_list),
  function(level) find_high_na(taxa_long_list[[level]], tax_cols[[level]])
))

cat("\nSamples with high unidentified fungal abundance:\n")
print(high_na_samples)

sample_removal <- high_na_samples |>
  filter(prop_na > 0.99) |>
  pull(Sample_ID) |>
  unique()

cat("\nSamples removed for >99% unidentified fungal abundance:\n")
print(sample_removal)

taxa_long_list <- lapply(taxa_long_list, removal, sample_removal)


# ---- Prepare Alpha Diversity Data ----

alpha_long <- data_list$alpha_div |>
  select(-SS_ID) |> # Kits experiments, not relevant here
  mutate(
    Fiber_restriction = na_if(Fiber_restriction, ""),
    Fiber_restriction = na_if(Fiber_restriction, "NA"),
    Fiber_restriction = if_else(is.na(Fiber_restriction), "None",
      Fiber_restriction
    ),
    Fiber_restriction = factor(
      Fiber_restriction,
      levels = c("None", "Low", "Mid", "High")
    )
  ) |>
  pivot_longer(
    -all_of(meta_cols),
    names_to = "Diversity_metric",
    values_to = "Value"
  )

# Apply the sample removal
alpha_long <- removal(alpha_long, sample_removal)


# ---- Identify Alpha Diversity Outliers ----

removal_diversity <- alpha_long |>
  group_by(Diversity_metric) |>
  mutate(
    Q1 = quantile(Value, 0.25, na.rm = TRUE),
    Q3 = quantile(Value, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1,
    is_outlier = Value < (Q1 - 1.5 * IQR) | Value > (Q3 + 1.5 * IQR)
  ) |>
  filter(is_outlier == TRUE) |>
  pull(Sample_ID)

cat("\nSamples removed as alpha diversity outliers (1.5 IQR):\n")
print(removal_diversity)


# ---- Apply Final Removals ----

taxa_long_list <- lapply(taxa_long_list, removal, removal_diversity)
alpha_long <- removal(alpha_long, removal_diversity)

cat("\nUnidentified outlier and diversity outlier removed from DF lists\n")

# ---- Save Wrangled Outputs ----

saveRDS(meta_data, "./data/intermediate/meta_data.rds")
saveRDS(taxa_long_list, "./data/intermediate/taxa_long_list.rds")
saveRDS(alpha_long, "./data/intermediate/alpha_long.rds")
saveRDS(sample_removal, "./data/intermediate/sample_removal.rds")
saveRDS(removal_diversity, "./data/intermediate/removal_diversity.rds")

message("02_data_wrangling.R completed: Data wrangled and saved.")
