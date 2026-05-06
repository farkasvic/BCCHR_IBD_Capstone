# BCCHR_IBD_Capstone

2026 MDS Capstone project in partnership with BC Children's Hospital Research Institute.
Team: Tiffany Chu, Victoria Farkas, Ian Gault, Derrick Jaskiel

## Overview

an analysis pipeline for IBD data

## Structure

- `data/raw`: raw input files
- `data/intermediate`: pipeline intermediates
- `data/processed`: processed outputs
- `figures/mycobiome`: generated figures
- `src/mycobiome`: main R pipeline
- `src/characteristics`, `src/diet`, `src/merge_files.py`: utils

## Quick start

Run commands from the repository root

```sh
make setup
make python-env
make ALL
```

To see the available commands:

```sh
make help
```

## Common targets

```sh
make import
make wrangle
make save
make clean
make r-check
make python-check
```

## All Commands (so far)
```sh
make help
make setup
make snapshot
make renv-status
make renv-clean
make python-env
make python-prune
make python-check
make r-check
make import
make wrangle
make diversity
make diversity-stats
make abundance
make heatmap
make save
make clean
make ALL
```
