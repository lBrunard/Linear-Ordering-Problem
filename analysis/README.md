# Analysis scripts (R)

These scripts are used to compute statistics and generate the plots in the report. They are **not** part of the deliverables but are included here for reproducibility.

## Requirements

- R (tested with R 4.5)
- R packages: `ggplot2`, `dplyr`, `tidyr`, `ggrepel`

## Usage

Run from the project root:

```bash
# Statistical tests (Wilcoxon, summary stats)
Rscript analysis/statistical_tests.R

# Generate all plots for the report
Rscript analysis/generate_plots.R
```

### Outputs

`statistical_tests.R` produces (in `results/`):
- `summary_statistics.csv` — average RPD, SD, and time per configuration
- `wilcoxon_ex1_1.csv` — pairwise Wilcoxon results for Exercise 1.1
- `wilcoxon_ex1_2.csv` — Wilcoxon result for VND-TEI vs VND-TIE

`generate_plots.R` produces PNG charts in `report/plots/`.
