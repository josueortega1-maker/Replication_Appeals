/**********************************************************************
 04_validation.do

 Checks generated samples and key estimates against independently
 verified targets. Tolerances allow for minor version-specific numerical
 differences in nonlinear post-estimation.
**********************************************************************/

version 18

/* Core sample checks */
use "$DER/analysis_sample.dta", clear
assert _N == 10195
quietly count if !missing(age, female, risk_aversion)
assert r(N) == 10185

quietly summarize truthful if treatment == 5, meanonly
assert abs(r(mean) - .3922388) < 1e-6
quietly summarize welfare_points if treatment == 5, meanonly
assert abs(r(mean) - 9.704477) < 1e-5
quietly summarize welfare_points if treatment == 6, meanonly
assert abs(r(mean) - 8.356205) < 1e-5

/* Appeal opportunities */
use "$DER/appeal_opportunities.dta", clear
assert _N == 5725
quietly count if treatment == 2
assert r(N) == 1845
quietly count if treatment == 5
assert r(N) == 979
quietly count if treatment == 5 & appeal_taken == 1
assert r(N) == 631
quietly count if treatment == 5 & appeal_success == 1
assert r(N) == 166

/* Complete markets and Pareto comparisons */
use "$DER/market_rounds.dta", clear
assert _N == 1435
quietly count if treatment == 6
assert r(N) == 236
quietly count if treatment == 6 & strict_pareto_da == 1
assert r(N) == 27
quietly count if treatment == 5
assert r(N) == 235
quietly count if treatment == 5 & strict_pareto_da == 1
assert r(N) == 112

/* Welfare decomposition must add exactly, up to storage precision */
use "$DER/table5_welfare_decomposition.dta", clear
gen double decomposition_error = total - reporting - direct
assert abs(decomposition_error) < 1e-8
quietly summarize total if treatment == 5, meanonly
assert abs(r(mean) - 1.348272) < 1e-5
quietly summarize reporting if treatment == 5, meanonly
assert abs(r(mean) - .813944) < 1e-5
quietly summarize direct if treatment == 5, meanonly
assert abs(r(mean) - .534328) < 1e-5

/* Nonlinear treatment effects: allow small software-version differences */
use "$DER/table2_truth_telling_estimates.dta", clear
quietly summarize estimate if row == 1 & spec == 1, meanonly
assert abs(r(mean) - .1142) < .002
quietly summarize estimate if row == 2 & spec == 1, meanonly
assert abs(r(mean) - .1104) < .002

use "$DER/table4_rank_estimates.dta", clear
quietly summarize estimate if row == 1 & spec == 1, meanonly
assert abs(r(mean) + .2698) < .003
quietly summarize estimate if row == 5 & spec == 4, meanonly
assert abs(r(mean) - .2723) < .003

use "$DER/table3_appeal_use_estimates.dta", clear
quietly summarize estimate if row == 7 & col == 2, meanonly
assert abs(r(mean) - .0740) < .002

use "$DER/table6_stability_estimates.dta", clear
quietly summarize estimate if row == 1 & col == 1, meanonly
assert abs(r(mean) + .5157) < .003
quietly summarize estimate if row == 4 & col == 3, meanonly
assert abs(r(mean) + .3329) < .003


/* Table D.1: nonparametric matching-group tests */
use "$DER/tableD1_nonparametric_estimates.dta", clear
assert _N == 28

/* IA strict - IA no appeals: full-ranking truth-telling */
quietly summarize estimate if row == 3 & col == 1, meanonly
assert abs(r(mean) - .0925974) < 1e-6
quietly summarize pvalue if row == 3 & col == 1, meanonly
assert abs(r(mean) - .1218910) < 1e-6

/* IA probabilistic - IA no appeals: full-ranking truth-telling */
quietly summarize estimate if row == 4 & col == 1, meanonly
assert abs(r(mean) - .0964286) < 1e-6
quietly summarize pvalue if row == 4 & col == 1, meanonly
assert abs(r(mean) - .0055165) < 1e-6

/* IA - DA under probabilistic appeals: truth and procedural stability */
quietly summarize estimate if row == 7 & col == 1, meanonly
assert abs(r(mean) - .0531716) < 1e-6
quietly summarize pvalue if row == 7 & col == 1, meanonly
assert abs(r(mean) - .0265658) < 1e-6
quietly summarize estimate if row == 7 & col == 3, meanonly
assert abs(r(mean) + .05) < 1e-8
quietly summarize pvalue if row == 7 & col == 3, meanonly
assert abs(r(mean) - .4199572) < 1e-6

/* Degenerate DA strict versus DA no-appeals stability outcomes */
quietly count if row == 1 & inlist(col, 3, 4) & degenerate == 1
assert r(N) == 2

/* Largest comparison uses 12 IA-probabilistic and 11 DA-probabilistic groups */
quietly count if row == 7 & n1 == 12 & n0 == 11
assert r(N) == 4

display as result "All replication validation checks passed."
clear
