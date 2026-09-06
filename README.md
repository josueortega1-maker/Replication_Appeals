# School Choice with Appeals: Stata replication package

## Quick start

1. Open Stata 18 or later.
2. Set the working directory to the root of this package.
3. Run:

```stata
do 00_master.do
```

The master file creates all analysis datasets, main tables, main figures, and diagnostic appendix outputs.

## Input data

The analysis starts from:

```text
data/sessions_long.dta
```

This file contains 10,220 participant-period records. The code removes 25 records collected after six participants had exited their sessions. The final paper sample contains 10,195 participant-period records. Models with personal controls contain 10,185 records because one participant has missing gender information.

## Treatment codes

| Code | Treatment |
|---:|---|
| 1 | DA probabilistic |
| 2 | DA strict |
| 3 | DA no appeals |
| 4 | IA probabilistic |
| 5 | IA strict |
| 6 | IA no appeals |

Tables and figures display treatments in the order no appeals, strict, probabilistic. Appeal-only outputs display strict before probabilistic.

## Code files

- `00_master.do`: runs the complete analysis.
- `code/01_prepare_data.do`: applies the paper exclusions, reconstructs first-stage assignments, builds school-specific appeal opportunities, constructs market-level stability outcomes, calculates Pareto comparisons, and computes unilateral truthful-report counterfactuals.
- `code/02_main_results.do`: produces Tables 1 to 6 and Figures 1 to 5.
- `code/03_appendix_results.do`: produces sample audits, treatment means, consequential-report results, appeal-opportunity diagnostics, and robustness figures.
- `code/04_validation.do`: checks key generated samples and estimates against independently verified targets.

## Main output

- `output/tables`: LaTeX table fragments.
- `output/figures`: PDF and PNG figures without internal titles.
- `output/data`: analysis-ready Stata and CSV files.
- `output/logs`: Stata logs.
- `replication_report.tex`: annotated standalone report that inputs every table and figure.

## Units of observation

The replication uses several units:

- participant-period for truth-telling, rank, and welfare;
- eligible participant-period for filing any appeal;
- school-specific appeal opportunity for filing a particular appeal;
- complete seven-person market-period for stability and Pareto dominance.

These samples are different by construction. The corresponding counts are reported in `output/data/sample_audit.csv` after the code runs.

## Inference

Treatment was assigned at the session-level matching group. Standard errors are clustered at that level throughout. Figure 4 follows the current paper and gives equal weight to each independent session. Table 6 follows the current paper regression and gives equal weight to each complete market-period while clustering by session. This difference is flagged in `INCONSISTENCIES.md`.

## Independent verification

The numeric targets in `verification/verified_targets.csv` were independently checked from the supplied data. The Stata code has been written for Stata 18, but Stata was not available in the file-construction environment. Researchers should inspect the log after the first run and compare the generated CSV files with the target file.

## Paper to output map

| Paper item | Replication output |
|---|---|
| Table 1 | `output/tables/table1_uphold_rules.tex` |
| Figure 1 | `output/figures/figure1_truth_telling.pdf` |
| Table 2 | `output/tables/table2_truth_telling.tex` |
| Figure 2 | `output/figures/figure2_appeal_takeup_success.pdf` |
| Table 3 | `output/tables/table3_appeal_use.tex` |
| Figure 3 | `output/figures/figure3_rank_welfare.pdf` |
| Table 4 | `output/tables/table4_assigned_rank.tex` |
| Pareto comparison | `output/tables/table_pareto_dominance.tex` |
| Table 5 | `output/tables/table5_welfare_decomposition.tex` |
| Figure 4 | `output/figures/figure4_stability.pdf` |
| Table 6 | `output/tables/table6_stability.tex` |
| Figure 5 | `output/figures/figure5_normalized_comparison.pdf` |

The TeX table fragments currently included in `output/tables` are independently checked snapshots. Stata overwrites them when `00_master.do` runs.
