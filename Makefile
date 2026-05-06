# Makefile for microbiome analysis pipeline

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
RESET := \033[0m

PY_ENV := bcchrcapstone
PY_ENV_FILE := environment.yaml
PY_SRC := src
R_SRC := src
MYCO_SRC := src/mycobiome

.PHONY: help setup snapshot renv-status renv-clean python-env python-prune python-check r-check process all clean import wrangle diversity diversity-stats abundance heatmap save

help:
	@printf "%b\n" "$(CYAN)Available commands:$(RESET)"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)renv setup:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make setup$(RESET)       - Install the exact R package versions recorded in renv.lock"
	@printf "%b\n" "  $(YELLOW)make snapshot$(RESET)    - Update renv.lock after adding or updating packages"
	@printf "%b\n" "  $(YELLOW)make renv-status$(RESET) - Show whether renv.lock and the library are in sync"
	@printf "%b\n" "  $(YELLOW)make renv-clean$(RESET)  - Interactively remove packages unused by the project"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)Python environment:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make python-env$(RESET)   - Create the conda environment from environment.yaml"
	@printf "%b\n" "  $(YELLOW)make python-prune$(RESET) - Update and prune the conda environment from environment.yaml"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)Python checks:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make python-check$(RESET) - Format Python files and run Ruff lint checks"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)R checks:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make r-check$(RESET) - Format R files and run lintr checks"
	@printf "%b\n" ""
	@printf "%b\n" "$(CYAN)Mycobiome Pipeline:$(RESET)"
	@printf "%b\n" "  $(YELLOW)make import$(RESET)      - Import raw data and save initial intermediates"
	@printf "%b\n" "  $(YELLOW)make wrangle$(RESET)     - Perform data wrangling and filtering"
	@printf "%b\n" "  $(YELLOW)make diversity$(RESET)   - Create alpha diversity plots"
	@printf "%b\n" "  $(YELLOW)make diversity-stats$(RESET) - Run pre-specified alpha diversity statistics"
	@printf "%b\n" "  $(YELLOW)make abundance$(RESET)   - Create relative abundance plots"
	@printf "%b\n" "  $(YELLOW)make heatmap$(RESET)     - Generate heatmaps from filtered taxa data"
	@printf "%b\n" "  $(YELLOW)make save$(RESET)        - Save processed datasets and combined taxa table"
	@printf "%b\n" "  $(YELLOW)make clean$(RESET)       - Remove intermediate and generated files"
	@printf "%b\n" "  $(YELLOW)make ALL$(RESET)         - Run the full data processing pipeline (no stats)"

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

python-env:
	@printf "%b\n" "$(CYAN)Creating Python conda environment from $(PY_ENV_FILE)...$(RESET)"
	conda env create -f $(PY_ENV_FILE)
	@printf "%b\n" "$(GREEN)Python environment created. Activate with: conda activate $(PY_ENV)$(RESET)"

python-prune:
	@printf "%b\n" "$(CYAN)Updating and pruning Python conda environment...$(RESET)"
	conda env update -n $(PY_ENV) -f $(PY_ENV_FILE) --prune
	@printf "%b\n" "$(GREEN)Python environment updated and pruned.$(RESET)"

python-check:
	@printf "%b\n" "$(CYAN)Formatting Python files with Ruff...$(RESET)"
	conda run -n $(PY_ENV) ruff format $(PY_SRC)
	@printf "%b\n" "$(CYAN)Running Ruff lint checks...$(RESET)"
	conda run -n $(PY_ENV) ruff check $(PY_SRC)
	@printf "%b\n" "$(GREEN)Python formatting and lint checks complete.$(RESET)"

r-check:
	@printf "%b\n" "$(CYAN)Formatting R files with styler...$(RESET)"
	XDG_CACHE_HOME=/tmp Rscript --vanilla -e "styler::style_dir('$(R_SRC)')"
	@printf "%b\n" "$(CYAN)Running lintr checks...$(RESET)"
	Rscript --vanilla -e "lints <- lintr::lint_dir('$(R_SRC)', linters = lintr::linters_with_defaults(object_usage_linter = NULL)); print(lints); quit(status = length(lints) > 0)"
	@printf "%b\n" "$(GREEN)R formatting and lint checks complete.$(RESET)"

ALL:
	@printf "%b\n" "$(CYAN)Running full processing pipeline...$(RESET)"
	Rscript $(MYCO_SRC)/01_data_import.R
	Rscript $(MYCO_SRC)/02_data_wrangling.R
	Rscript $(MYCO_SRC)/03_diversity_analysis.R
	Rscript $(MYCO_SRC)/04_abundance_analysis.R
	Rscript $(MYCO_SRC)/05_heatmap_analysis.R
	Rscript $(MYCO_SRC)/06_save_processed.R
	@printf "%b\n" "$(GREEN)Processing complete.$(RESET)"

clean:
	@printf "%b\n" "$(YELLOW)Cleaning intermediate and generated files...$(RESET)"
	@rm -f data/intermediate/*.rds data/intermediate/*.csv data/intermediate/*.xlsx
	@rm -f data/processed/*.rds data/processed/*.csv data/processed/*.xlsx
	@rm -f figures/mycobiome/*.png figures/mycobiome/*.jpg figures/mycobiome/*.jpeg figures/mycobiome/*.tiff figures/mycobiome/*.pdf
	@rm -f notebooks/*.nb.html notebooks/*.html notebooks/*.pdf
	@printf "%b\n" "$(GREEN)Clean complete.$(RESET)"

import:
	@printf "%b\n" "$(CYAN)Importing raw data...$(RESET)"
	Rscript $(MYCO_SRC)/01_data_import.R
	@printf "%b\n" "$(GREEN)Import complete.$(RESET)"

wrangle:
	@printf "%b\n" "$(CYAN)Wrangling data...$(RESET)"
	Rscript $(MYCO_SRC)/02_data_wrangling.R
	@printf "%b\n" "$(GREEN)Wrangle complete.$(RESET)"

diversity:
	@printf "%b\n" "$(CYAN)Creating diversity plots...$(RESET)"
	Rscript $(MYCO_SRC)/03_diversity_analysis.R
	@printf "%b\n" "$(GREEN)Diversity plots complete.$(RESET)"

diversity-stats:
	@printf "%b\n" "$(CYAN)Running pre-specified diversity statistics...$(RESET)"
	Rscript --vanilla $(MYCO_SRC)/03b_diversity_stats.R
	@printf "%b\n" "$(GREEN)Diversity statistics complete.$(RESET)"

abundance:
	@printf "%b\n" "$(CYAN)Creating abundance plots...$(RESET)"
	Rscript $(MYCO_SRC)/04_abundance_analysis.R
	@printf "%b\n" "$(GREEN)Abundance plots complete.$(RESET)"

heatmap:
	@printf "%b\n" "$(CYAN)Generating heatmaps...$(RESET)"
	Rscript $(MYCO_SRC)/05_heatmap_analysis.R
	@printf "%b\n" "$(GREEN)Heatmap generation complete.$(RESET)"

save:
	@printf "%b\n" "$(CYAN)Saving processed outputs...$(RESET)"
	Rscript $(MYCO_SRC)/06_save_processed.R
	@printf "%b\n" "$(GREEN)Save complete.$(RESET)"
