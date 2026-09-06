# School Choice with Appeals — Replication Package

Replication code and data for **"School Choice with Appeals"** by Claudia Cerrone, Yoan Hermstrüwer and Josué Ortega.

📄 Paper: [arXiv:XXXX.XXXXX](https://arxiv.org/abs/XXXX.XXXXX) · 📋 Pre-registration: [OSF](https://osf.io/q92de/)

## Quick start

Requires **Stata 18 or later**. Set the working directory to the root of this package and run:

```stata
do 00_master.do
```

This builds every analysis dataset, table and figure in the paper from the raw experimental data.

<!-- List any user-written commands the code relies on, e.g.:
Before the first run, install: `ssc install estout, replace`
-->

## Data

`data/sessions_long.dta` contains 10,220 participant-period records from a laboratory experiment with 1,022 participants across 59 independent matching groups, conducted at EssexLab, University of Essex.

The code drops 25 records collected after participants had exited their sessions, giving a paper sample of 10,195. Specifications with demographic controls use 10,185 records, since one participant has missing gender information.

Participants are identified only by an arbitrary sequential number. No information that could identify an individual participant is included. The experiment received ethics approval from City St George's, University of London.

Treatment codes: 1 = DA probabilistic, 2 = DA strict, 3 = DA no appeals, 4 = IA probabilistic, 5 = IA strict, 6 = IA no appeals.

## Structure

```
00_master.do              Runs everything
code/
  01_prepare_data.do      Exclusions, first-stage assignments, appeal
                          opportunities, stability, Pareto comparisons,
                          truthful-report counterfactuals
  02_main_results.do      Tables 1–6, Figures 1–5
  03_appendix_results.do  Sample audits, treatment means, robustness
  04_validation.do        Checks estimates against verified targets
  05_full_takeup.do       Appendix E: full appeal take-up benchmark
data/                     Input data
output/                   Tables, figures, logs, analysis datasets
verification/             Independently checked numeric targets
DATA_DICTIONARY.md        Variable definitions
INCONSISTENCIES.md        Known discrepancies and how they arose
```

## Units of observation

Different results use different units, and the samples differ by construction:

| Outcome | Unit |
|---|---|
| Truth-telling, assigned rank, welfare | Participant-period |
| Filing any appeal | Eligible participant-period |
| Filing a particular appeal | School-specific appeal opportunity |
| Stability, Pareto dominance | Complete seven-person market-period |

Counts for each are written to `output/data/sample_audit.csv`.

## Inference

Treatment was assigned at the session-level matching group, and standard errors are clustered at that level throughout. Figure 4 weights each independent session equally; Table 6 weights each complete market-period equally while clustering by session. This difference is documented in `INCONSISTENCIES.md`.

## Paper to output map

| Paper item | File |
|---|---|
| Table 1 | `output/tables/table1_uphold_rules.tex` |
| Figure 1 | `output/figures/figure1_truth_telling.pdf` |
| Table 2 | `output/tables/table2_truth_telling.tex` |
| Figure 2 | `output/figures/figure2_appeal_takeup_success.pdf` |
| Table 3 | `output/tables/table3_appeal_use.tex` |
| Figure 3 | `output/figures/figure3_rank_welfare.pdf` |
| Table 4 | `output/tables/table4_assigned_rank.tex` |
| Table 5 | `output/tables/table5_welfare_decomposition.tex` |
| Figure 4 | `output/figures/figure4_stability.pdf` |
| Table 6 | `output/tables/table6_stability.tex` |
| Figure 5 | `output/figures/figure5_normalized_comparison.pdf` |
| Pareto comparison | `output/tables/table_pareto_dominance.tex` |

`replication_report.tex` compiles every table and figure into a single standalone document.

The `.tex` fragments currently in `output/tables` are snapshots; Stata overwrites them on each run.

## Citation

```bibtex
@unpublished{cerrone2026school,
  author = {Cerrone, Claudia and Hermstrüwer, Yoan and Ortega, Josué},
  title  = {School Choice with Appeals},
  year   = {2026},
  note   = {arXiv:XXXX.XXXXX}
}
```

## License

Code released under the MIT License. Data released under CC BY 4.0.

## Contact

Questions and bug reports: [open an issue](../../issues) or email j.ortega@qub.ac.uk.
