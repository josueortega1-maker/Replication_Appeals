# Data dictionary for the replication package

## Original input

The only required input is `data/sessions_long.dta`. It contains one record per participant and period before the documented post-exit exclusions.

Key source variables:

| Variable | Description |
|---|---|
| `session` | Numeric session-level matching-group identifier and inference cluster |
| `sessioncode` | String session identifier |
| `participantid_in_session` | Participant identifier within session |
| `round` | Experimental period, from 1 to 10 |
| `groupid` | Seven-person market identifier within session and period |
| `id_in_group` | Induced student type, from 1 to 7 |
| `treatment` | Treatment code, documented in `README.md` |
| `choice1`, `choice2`, `choice3` | Submitted rank-order list |
| `assignedschool` | Final assignment after any appeal stage |
| `assigned_rank` | Final assignment rank under induced preferences, with unmatched coded as 4 |
| `welfare_points` | Final experimental points |
| `truthful` | Complete induced ranking submitted |
| `top_choice_truth` | Induced first choice ranked first |
| `offered_appeal` | At least one appeal opportunity was available |
| `appealed_any` | At least one appeal was filed |
| `any_success` | At least one filed appeal was upheld |
| `n_rejected` | Number of rejected schools before the first-stage assignment |
| `age`, `female`, `risk_aversion` | Personal controls |

The wide appeal fields follow the pattern `ranking#playerappeal_school_#`, `ranking#playerappeal_choice_#`, and `ranking#playerappeal_result_#`.

## Main generated participant-period data

`output/data/analysis_sample.dta` contains the 10,195-record paper sample. Important generated variables include:

| Variable | Description |
|---|---|
| `paper_sample` | Equals one for the agreed paper sample |
| `IA` | Immediate Acceptance treatment indicator |
| `strict_rule` | Strict appeal treatment indicator |
| `probabilistic_rule` | Probabilistic appeal treatment indicator |
| `first_stage_n` | Reconstructed assignment before appeals |
| `first_stage_rank` | First-stage assignment rank under induced preferences |
| `first_stage_points` | First-stage experimental points |
| `direct_appeal_gain` | Final points minus first-stage points |
| `simulated_first_stage_n` | First-stage assignment reconstructed from all submitted reports |
| `truthful_counterfactual_n` | Focal assignment when only the focal report is replaced with the induced ranking |
| `consequential` | Non-truthful report changes the focal first-stage assignment |
| `beneficial` | Observed non-truthful report yields more points than the unilateral truthful counterfactual |
| `harmful` | Observed non-truthful report yields fewer points than the unilateral truthful counterfactual |

## Appeal-opportunity data

`output/data/appeal_opportunities.dta` contains one record for each school-specific appeal opportunity. Key variables:

| Variable | Description |
|---|---|
| `appeal_school` | Rejected school that could be challenged |
| `appeal_taken` | Appeal was filed |
| `appeal_result` | Appeal was upheld |
| `target_rank` | Appealed school's rank under induced preferences |
| `strict_claim` | Appellant has strictly higher underlying priority than at least one first-stage occupant |
| `gain_rank` | Improvement from the first-stage assignment to the target school |
| `appeal_success` | Filed appeal was upheld |
| `appeal_useful` | Upheld appeal improved the focal participant's final assignment |

`output/data/appeal_rounds.dta` aggregates these records to eligible participant-periods.

## Market-period data

`output/data/market_rounds.dta` contains one record for each complete seven-person market-period. Key variables:

| Variable | Description |
|---|---|
| `strict_bp_sub` | Number of strict blocking pairs under submitted preferences |
| `waste_sub` | Number of wasted-seat claims under submitted preferences |
| `stable_sub` | No strict blocking pair and no wasted-seat claim under submitted preferences |
| `strict_bp_true` | Number of strict blocking pairs under induced preferences |
| `waste_true` | Number of wasted-seat claims under induced preferences |
| `stable_true` | No strict blocking pair and no wasted-seat claim under induced preferences |
| `weak_pareto_da` | Every role is weakly better off than under truthful DA |
| `strict_pareto_da` | Weak dominance and at least one role strictly better off than under truthful DA |

Strict priority comparisons use the underlying weak priority classes. The first-stage tie-break is not treated as a strict priority difference.
