# Makefile for microbiome analysis pipeline

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
RESET := \033[0m

.PHONY: help setup snapshot renv-status renv-clean process all clean import wrangle diversity abundance heatmap save

help:
	@printf "%b\n" "$(CYAN)Available commands:$(RESET)"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)renv setup:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make setup$(RESET)       - Install the exact R package versions recorded in renv.lock"
	@printf "%b\n" "  $(YELLOW)make snapshot$(RESET)    - Update renv.lock after adding or updating packages"
	@printf "%b\n" "  $(YELLOW)make renv-status$(RESET) - Show whether renv.lock and the library are in sync"
	@printf "%b\n" "  $(YELLOW)make renv-clean$(RESET)  - Interactively remove packages unused by the project"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)Mycobiome Pipeline:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make process$(RESET)     - Run the full data processing pipeline"
	@printf "%b\n" "  $(YELLOW)make import$(RESET)      - Import raw data and save initial intermediates"
	@printf "%b\n" "  $(YELLOW)make wrangle$(RESET)     - Perform data wrangling and filtering"
	@printf "%b\n" "  $(YELLOW)make diversity$(RESET)   - Run alpha diversity analysis and plots"
	@printf "%b\n" "  $(YELLOW)make abundance$(RESET)   - Create relative abundance plots"
	@printf "%b\n" "  $(YELLOW)make heatmap$(RESET)     - Generate heatmaps from filtered taxa data"
	@printf "%b\n" "  $(YELLOW)make save$(RESET)        - Save processed datasets and combined taxa table"
	@printf "%b\n" "  $(YELLOW)make all$(RESET)         - Clean generated outputs, then run the full pipeline"
	@printf "%b\n" "  $(YELLOW)make clean$(RESET)       - Remove intermediate and generated files"

setup:
	@printf "%b\n" "$(CYAN)Restoring renv environment from renv.lock...$(RESET)"
	Rscript -e "options(repos=c(CRAN='https://cran.rstudio.com/')); if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv'); renv::restore(prompt = FALSE)"
	@printf "%b\n" "$(GREEN)renv restore complete.$(RESET)"

snapshot:
	@printf "%b\n" "$(CYAN)Updating renv.lock from installed project packages...$(RESET)"
	Rscript -e "renv::snapshot(prompt = FALSE)"
	@printf "%b\n" "$(GREEN)renv snapshot complete.$(RESET)"

renv-status:
	@printf "%b\n" "$(CYAN)Checking renv status...$(RESET)"
	Rscript -e "renv::status()"

renv-clean:
	@printf "%b\n" "$(CYAN)Checking for packages unused by this project...$(RESET)"
	Rscript -e "renv::clean()"

process:
	@printf "%b\n" "$(CYAN)Running full processing pipeline...$(RESET)"
	Rscript src/01_data_import.R
	Rscript src/02_data_wrangling.R
	Rscript src/03_diversity_analysis.R
	Rscript src/04_abundance_analysis.R
	Rscript src/05_heatmap_analysis.R
	Rscript src/06_save_processed.R
	@printf "%b\n" "$(GREEN)Processing complete.$(RESET)"

all: clean process
	@printf "%b\n" "$(GREEN)Full workflow complete.$(RESET)"

clean:
	@printf "%b\n" "$(YELLOW)Cleaning intermediate and generated files...$(RESET)"
	@rm -rf data/intermediate/*.rds
	@rm -f data/processed/*.csv
	@rm -f figures/mycobiome/*.png
	@rm -f notebook/*.nb.html
	@printf "%b\n" "$(GREEN)Clean complete.$(RESET)"

import:
	@printf "%b\n" "$(CYAN)Importing raw data...$(RESET)"
	Rscript src/01_data_import.R
	@printf "%b\n" "$(GREEN)Import complete.$(RESET)"

wrangle:
	@printf "%b\n" "$(CYAN)Wrangling data...$(RESET)"
	Rscript src/02_data_wrangling.R
	@printf "%b\n" "$(GREEN)Wrangle complete.$(RESET)"

diversity:
	@printf "%b\n" "$(CYAN)Running diversity analysis...$(RESET)"
	Rscript src/03_diversity_analysis.R
	@printf "%b\n" "$(GREEN)Diversity analysis complete.$(RESET)"

abundance:
	@printf "%b\n" "$(CYAN)Creating abundance plots...$(RESET)"
	Rscript src/04_abundance_analysis.R
	@printf "%b\n" "$(GREEN)Abundance plots complete.$(RESET)"

heatmap:
	@printf "%b\n" "$(CYAN)Generating heatmaps...$(RESET)"
	Rscript src/05_heatmap_analysis.R
	@printf "%b\n" "$(GREEN)Heatmap generation complete.$(RESET)"

save:
	@printf "%b\n" "$(CYAN)Saving processed outputs...$(RESET)"
	Rscript src/06_save_processed.R
	@printf "%b\n" "$(GREEN)Save complete.$(RESET)"
