library(shiny)
library(ggplot2)
library(plotly)
library(dplyr)
library(tidyr)
library(readxl)

source(file.path("R", "cards.R"), local = TRUE)
source(file.path("R", "plots.R"), local = TRUE)

# Separate diet and taxa datasets and remove taxa tags from column names
diet <- read_excel("../data/processed/dietary_cleaned.xlsx")

phylum <- read.csv("../data/processed/phylum.csv")
names(phylum) <- sub("^p__", "", names(phylum))

family <- read.csv("../data/processed/family.csv")
names(family) <- sub("^f__", "", names(family))

species <- read.csv("../data/processed/species.csv")
names(species) <- sub("^s__", "", names(species))

genus <- read.csv("../data/processed/genus.csv")
names(genus) <- sub("^g__", "", names(genus))

# merged characteristics_genus_species_dietary_inner.csv from processed file
participant_data <- read.csv(
  "../data/processed/characteristics_genus_species_dietary_inner.csv",
  stringsAsFactors = FALSE
)

participants <- participant_data %>%
  transmute(
    ID = participant_id,
    Age = age,
    Sex = gender,
    Ethnicity = ethnicity,
    Country_of_Origin = country_of_origin,
    Years_Living_in_Canada = years_living_in_canada,
    Weight_lbs = weight_.lbs.,
    Height_cm = height_.cm.,
    Exercise_History = exercise_history,
    Comorbidities = comorbidities,
    Family_History_of_IBD = family_history_of_ibd,
    Smoking_Status = smoking_status,
    Alcohol_Intake = alcohol_intake,
    Prebiotics = supp_prebiotics,
    Probiotics = probiotics,
    Harvey_Bradshaw_Index = harvey_bradshaw_index,
    General_Well_Being = general_well.being,
    Abdominal_Pain = abdominal_pain,
    Daily_Soft_Stools = daily_soft_stools,
    Advanced_Therapy_Changes = advanced_therapy_changes,
    Fatigue_Frequency = fatigue_frequency,
    Anxiety_Frequency = anxiety_frequency,
    Sleep_Difficulty_Frequency = sleep_difficulty_frequency,
    Abdominal_Bloating_Frequency = abdominal_bloating_frequency,
    Rectal_Bleeding_Frequency = rectal_bleeding_frequency,
    Feeling_Unwell_Frequency = feeling_unwell_frequency,
    Fruit_Avoidance_Active = fruit_avoidance_active,
    Excluded_Fruits_Active = excluded_fruits_active,
    Vegetable_Avoidance_Active = vegetable_avoidance_active,
    Excluded_Vegetables_Active = excluded_vegetables_active,
    Whole_Grain_Avoidance_Active = whole_grain_avoidance_active,
    Excluded_Whole_Grains_Active = excluded_whole_grains_active,
    Nut_Seed_Avoidance_Active = nut_seed_avoidance_active,
    Excluded_Nuts_Seeds_Active = excluded_nuts_seeds_active,
    Lactose_Avoidance_Active = lactose_avoidance_active,
    Excluded_Lactose_Active = excluded_lactose_active,
    Gluten_Avoidance_Active = gluten_avoidance_active,
    Excluded_Gluten_Active = excluded_gluten_active,
    Spicy_Food_Avoidance_Active = spicy_food_avoidance_active,
    Excluded_Spicy_Foods_Active = excluded_spicy_foods_active,
    Fat_Food_Avoidance_Active = fat_food_avoidance_active,
    Excluded_Fat_Foods_Active = exclued_fat_foods_active,
    Fruit_Avoidance_Remission = fruit_avoidance_rem,
    Excluded_Fruits_Remission = excluded_fruits_rem,
    Vegetable_Avoidance_Remission = vegetable_avoidance_rem,
    Excluded_Vegetables_Remission = excluded_vegetables_rem,
    Whole_Grain_Avoidance_Remission = whole_grain_avoidance_rem,
    Excluded_Whole_Grains_Remission = excluded_whole_grains_rem,
    Nut_Seed_Avoidance_Remission = nut_seed_avoidance_rem,
    Excluded_Nuts_Seeds_Remission = excluded_nuts_seeds_rem,
    Lactose_Avoidance_Remission = lactose_avoidance_rem,
    Excluded_Lactose_Remission = excluded_lactose_rem,
    Gluten_Avoidance_Remission = gluten_avoidance_rem,
    Excluded_Gluten_Remission = excluded_gluten_rem,
    Spicy_Food_Avoidance_Remission = spicy_food_avoidance_rem,
    Excluded_Spicy_Foods_Remission = excluded_spicy_foods_rem,
    Fat_Food_Avoidance_Remission = fat_food_avoidance_rem,
    Excluded_Fat_Foods_Remission = excluded_fat_foods_rem
  ) %>%
  distinct(ID, .keep_all = TRUE)

score_columns <- c(
  "MPGrain..oz.eq.",
  "MPVeg..c.eq.",
  "MPFruit..c.eq.",
  "MPDairy..c.eq.",
  "MPProt..oz.eq.",
  "TotFib..g."
)

cfg_targets <- c(
  "MPGrain..oz.eq." = 5.0,
  "MPVeg..c.eq." = 2.5,
  "MPFruit..c.eq." = 2.0,
  "MPDairy..c.eq." = 2.0,
  "MPProt..oz.eq." = 5.5
)

format_prevalence <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value)) {
    return("NA")
  }
  if (value %in% c(1, "1")) {
    return("Yes")
  }
  if (value %in% c(0, "0")) {
    return("No")
  }
  as.character(value)
}

get_fibre_target <- function(sex_value) {
  sex_clean <- ""
  if (!is.null(sex_value) && length(sex_value) > 0 && !is.na(sex_value[1])) {
    sex_clean <- tolower(trimws(as.character(sex_value[1])))
  }
  if (sex_clean %in% c("female", "woman", "f")) {
    return(25.0)
  }
  if (sex_clean %in% c("male", "man", "m")) {
    return(38.0)
  }
  NA_real_
}

format_missing <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value) || trimws(as.character(value)) == "") {
    return("NA")
  }
  as.character(value)
}

format_avoidance_detail <- function(summary_value, excluded_value) {
  summary_text <- format_missing(summary_value)
  excluded_text <- format_missing(excluded_value)
  if (excluded_text == "NA" || identical(summary_text, "No avoidance")) {
    return(summary_text)
  }
  paste0(summary_text, " (", excluded_text, ")")
}
