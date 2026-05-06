# 01_data_import.R: Setup, libraries, data import, and theme

# ---- Setup ----

rm(list = ls())

library(readxl)
library(janitor)


# ---- Import Raw Mycobiome Tables ----

file_path <- "./data/raw/OPT_stool mycobiota relative abund.xlsx"
sheets <- excel_sheets(file_path)
data_list <- setNames(
  lapply(sheets, function(s) {
    read_excel(file_path, sheet = s)
  }),
  make_clean_names(sheets)
)

meta_raw <- read_excel("./data/raw/OPT_MBI sample IDs meta.xlsx")


# ---- Save Imported Data ----

saveRDS(data_list, "./data/intermediate/data_list.rds")
saveRDS(meta_raw, "./data/intermediate/meta_raw.rds")

message("01_data_import.R completed: Data imported and saved.")
