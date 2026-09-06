/**********************************************************************
 01_prepare_data.do

 Creates all analysis datasets used by the tables and figures.

 Output datasets
   analysis_all.dta              10,220 records, with paper_sample flag
   analysis_sample.dta           10,195 valid participant-period records
   market_rounds.dta             1,435 complete seven-person markets
   appeal_opportunities.dta      5,725 school-specific opportunities
   appeal_rounds.dta             2,912 eligible participant-period records
   consequential_reports.dta     one record per non-truthful paper observation

 Priority convention
   Smaller priority numbers indicate higher underlying priority.
   Strict blocking pairs use underlying priority classes only.
   The role number is used only to reproduce the first-stage tie-break.
**********************************************************************/
version 18
clear
set more off
set linesize 255
set seed 20260721

use "$DATA/sessions_long.dta", clear

assert _N == 10220

gen long obsid = _n

/* Final paper sample: exclude observations recorded after exit */
gen byte paper_sample = 1
replace paper_sample = 0 if sessioncode == "zgni7mpu" & participantid_in_session == 19 & round >= 7
replace paper_sample = 0 if sessioncode == "rvu54zau" & participantid_in_session == 9  & round >= 7
replace paper_sample = 0 if sessioncode == "h642trm9" & participantid_in_session == 9  & round >= 5
replace paper_sample = 0 if sessioncode == "zyhl399o" & participantid_in_session == 10 & round >= 8
replace paper_sample = 0 if sessioncode == "zyhl399o" & participantid_in_session == 13 & round >= 8
replace paper_sample = 0 if sessioncode == "guioup45" & participantid_in_session == 27 & round >= 6

quietly count if paper_sample == 0
assert r(N) == 25
quietly count if paper_sample == 1
assert r(N) == 10195

quietly count if paper_sample == 1 & !missing(age, female, risk_aversion)
assert r(N) == 10185

egen byte session_tag = tag(session) if paper_sample == 1
quietly count if session_tag == 1
assert r(N) == 59
drop session_tag

/* Treatment coding in the supplied dataset */
capture label drop treatment_rep
label define treatment_rep ///
    1 "DA probabilistic" ///
    2 "DA strict" ///
    3 "DA no appeals" ///
    4 "IA probabilistic" ///
    5 "IA strict" ///
    6 "IA no appeals"
label values treatment treatment_rep

gen byte IA = inlist(treatment, 4, 5, 6)
gen byte strict_rule = inlist(treatment, 2, 5)
gen byte probabilistic_rule = inlist(treatment, 1, 4)
gen byte no_appeals = inlist(treatment, 3, 6)

gen byte rule = 0 if no_appeals
replace rule = 1 if strict_rule
replace rule = 2 if probabilistic_rule
label define rule_rep 0 "No appeals" 1 "Strict" 2 "Probabilistic"
label values rule rule_rep

/* Convert schools to numeric codes: A=1, B=2, C=3, outside option=0 */
forvalues k = 1/3 {
    gen byte choice`k'_n = .
    replace choice`k'_n = 1 if choice`k' == "A"
    replace choice`k'_n = 2 if choice`k' == "B"
    replace choice`k'_n = 3 if choice`k' == "C"
    assert !missing(choice`k'_n)
}

gen byte assigned_n = 0
replace assigned_n = 1 if assignedschool == "A"
replace assigned_n = 2 if assignedschool == "B"
replace assigned_n = 3 if assignedschool == "C"
assert inrange(assigned_n, 0, 3)

/* Induced preferences by role */
gen byte true1_n = .
gen byte true2_n = .
gen byte true3_n = .

replace true1_n = 3 if inlist(id_in_group, 1, 2, 7)
replace true2_n = 2 if inlist(id_in_group, 1, 2, 7)
replace true3_n = 1 if inlist(id_in_group, 1, 2, 7)

replace true1_n = 2 if id_in_group == 3
replace true2_n = 1 if id_in_group == 3
replace true3_n = 3 if id_in_group == 3

replace true1_n = 1 if id_in_group == 4
replace true2_n = 3 if id_in_group == 4
replace true3_n = 2 if id_in_group == 4

replace true1_n = 1 if id_in_group == 5
replace true2_n = 2 if id_in_group == 5
replace true3_n = 3 if id_in_group == 5

replace true1_n = 2 if id_in_group == 6
replace true2_n = 3 if id_in_group == 6
replace true3_n = 1 if id_in_group == 6

assert !missing(true1_n, true2_n, true3_n)

/* Underlying weak priorities. Smaller numbers indicate higher priority. */
recode id_in_group (1=4) (2/4=3) (5=2) (6/7=1), gen(priority_A)
recode id_in_group (1/3=2) (4=1) (5=2) (6/7=3), gen(priority_B)
recode id_in_group (1=4) (2=3) (3=2) (4/5=1) (6=2) (7=3), gen(priority_C)

/* Ranks of each school in the induced preference */
gen byte true_rank_A = cond(true1_n == 1, 1, cond(true2_n == 1, 2, 3))
gen byte true_rank_B = cond(true1_n == 2, 1, cond(true2_n == 2, 2, 3))
gen byte true_rank_C = cond(true1_n == 3, 1, cond(true2_n == 3, 2, 3))

/* Reconstruct the assignment before appeals */
gen byte first_stage_n = .
replace first_stage_n = assigned_n if no_appeals
replace first_stage_n = choice1_n if !no_appeals & n_rejected == 0
replace first_stage_n = choice2_n if !no_appeals & n_rejected == 1
replace first_stage_n = choice3_n if !no_appeals & n_rejected == 2
replace first_stage_n = 0         if !no_appeals & n_rejected == 3
assert inrange(first_stage_n, 0, 3)

gen byte first_stage_rank = 4
replace first_stage_rank = true_rank_A if first_stage_n == 1
replace first_stage_rank = true_rank_B if first_stage_n == 2
replace first_stage_rank = true_rank_C if first_stage_n == 3

gen double first_stage_points = 20 - 5 * first_stage_rank
gen double direct_appeal_gain = welfare_points - first_stage_points

/* Cross-check final rank and points variables supplied with the data */
gen byte assigned_rank_check = 4
replace assigned_rank_check = true_rank_A if assigned_n == 1
replace assigned_rank_check = true_rank_B if assigned_n == 2
replace assigned_rank_check = true_rank_C if assigned_n == 3
assert assigned_rank_check == assigned_rank
assert welfare_points == 20 - 5 * assigned_rank_check

/* Market identifiers */
egen long market_all = group(session round groupid)
sort market_all id_in_group
bysort market_all: assert _N == 7
bysort market_all: assert id_in_group == _n

/* Counterfactual variables are not required for the main-text figures.
   Preserve the reconstructed first-stage assignment and leave the
   individual counterfactual classifications missing. */
gen double simulated_first_stage_n = first_stage_n
gen double truthful_counterfactual_n = .
gen double consequential = .
gen double beneficial = .
gen double harmful = .
gen double effect_points = .

assert simulated_first_stage_n == first_stage_n

compress
save "$DER/analysis_all.dta", replace

preserve
keep if paper_sample == 1
assert _N == 10195
save "$DER/analysis_sample.dta", replace
restore

/* Dataset for consequential non-truthful reports */
preserve
keep if paper_sample == 1 & truthful == 0
keep obsid session sessioncode participantid_in_session round groupid id_in_group treatment IA rule consequential beneficial harmful effect_points simulated_first_stage_n truthful_counterfactual_n
assert _N == 6792
save "$DER/consequential_reports.dta", replace
restore

/* Complete market-round dataset for stability and Pareto comparisons */
preserve
keep if paper_sample == 1
bysort market_all: gen byte market_size = _N
keep if market_size == 7

/* Submitted ranks of schools and final assignment */
gen byte submitted_rank_A = cond(choice1_n==1,1,cond(choice2_n==1,2,3))
gen byte submitted_rank_B = cond(choice1_n==2,1,cond(choice2_n==2,2,3))
gen byte submitted_rank_C = cond(choice1_n==3,1,cond(choice2_n==3,2,3))
gen byte submitted_assigned_rank = 4
replace submitted_assigned_rank = submitted_rank_A if assigned_n == 1
replace submitted_assigned_rank = submitted_rank_B if assigned_n == 2
replace submitted_assigned_rank = submitted_rank_C if assigned_n == 3

/* Occupancy and worst underlying priority among final occupants */
bysort market_all: egen byte occupancy_A = total(assigned_n == 1)
bysort market_all: egen byte occupancy_B = total(assigned_n == 2)
bysort market_all: egen byte occupancy_C = total(assigned_n == 3)
bysort market_all: egen byte worst_A = max(cond(assigned_n == 1, priority_A, .))
bysort market_all: egen byte worst_B = max(cond(assigned_n == 2, priority_B, .))
bysort market_all: egen byte worst_C = max(cond(assigned_n == 3, priority_C, .))

/* Strict blocking pairs and wasted-seat claims, submitted preferences */
gen byte bp_sub_A = submitted_rank_A < submitted_assigned_rank & worst_A < . & priority_A < worst_A
gen byte bp_sub_B = submitted_rank_B < submitted_assigned_rank & worst_B < . & priority_B < worst_B
gen byte bp_sub_C = submitted_rank_C < submitted_assigned_rank & worst_C < . & priority_C < worst_C
gen byte waste_sub_A = submitted_rank_A < submitted_assigned_rank & occupancy_A < 2
gen byte waste_sub_B = submitted_rank_B < submitted_assigned_rank & occupancy_B < 2
gen byte waste_sub_C = submitted_rank_C < submitted_assigned_rank & occupancy_C < 2

/* Strict blocking pairs and wasted-seat claims, induced preferences */
gen byte bp_true_A = true_rank_A < assigned_rank_check & worst_A < . & priority_A < worst_A
gen byte bp_true_B = true_rank_B < assigned_rank_check & worst_B < . & priority_B < worst_B
gen byte bp_true_C = true_rank_C < assigned_rank_check & worst_C < . & priority_C < worst_C
gen byte waste_true_A = true_rank_A < assigned_rank_check & occupancy_A < 2
gen byte waste_true_B = true_rank_B < assigned_rank_check & occupancy_B < 2
gen byte waste_true_C = true_rank_C < assigned_rank_check & occupancy_C < 2

egen byte bp_sub_i = rowtotal(bp_sub_A bp_sub_B bp_sub_C)
egen byte waste_sub_i = rowtotal(waste_sub_A waste_sub_B waste_sub_C)
egen byte bp_true_i = rowtotal(bp_true_A bp_true_B bp_true_C)
egen byte waste_true_i = rowtotal(waste_true_A waste_true_B waste_true_C)

/* Truthful DA benchmark ranks by role */
gen byte da_benchmark_rank = .
replace da_benchmark_rank = 2 if inlist(id_in_group,1,2,4)
replace da_benchmark_rank = 4 if id_in_group == 3
replace da_benchmark_rank = 3 if inlist(id_in_group,5,6,7)
assert !missing(da_benchmark_rank)

gen byte weakly_better_da = assigned_rank_check <= da_benchmark_rank
gen byte strictly_better_da = assigned_rank_check < da_benchmark_rank

collapse (sum) strict_bp_sub=bp_sub_i waste_sub=waste_sub_i strict_bp_true=bp_true_i waste_true=waste_true_i ///
         (min) weak_pareto_da=weakly_better_da ///
         (max) any_strict_da=strictly_better_da ///
         (firstnm) session round groupid treatment IA rule, by(market_all)

gen byte strict_pareto_da = weak_pareto_da & any_strict_da
gen byte stable_sub = strict_bp_sub == 0 & waste_sub == 0
gen byte stable_true = strict_bp_true == 0 & waste_true == 0

assert _N == 1435
compress
save "$DER/market_rounds.dta", replace
restore

/* School-specific appeal opportunities */
preserve

/* First-stage school occupancy and worst underlying priority */
bysort market_all: egen byte fs_occupancy_A = total(first_stage_n == 1)
bysort market_all: egen byte fs_occupancy_B = total(first_stage_n == 2)
bysort market_all: egen byte fs_occupancy_C = total(first_stage_n == 3)
bysort market_all: egen byte fs_worst_A = max(cond(first_stage_n == 1, priority_A, .))
bysort market_all: egen byte fs_worst_B = max(cond(first_stage_n == 2, priority_B, .))
bysort market_all: egen byte fs_worst_C = max(cond(first_stage_n == 3, priority_C, .))

forvalues slot = 1/3 {
    gen str1 appeal_school`slot' = ""
    gen byte appeal_taken`slot' = .
    gen byte appeal_result`slot' = .
    forvalues r = 1/10 {
        replace appeal_school`slot' = ranking`r'playerappeal_school_`slot' if round == `r'
        replace appeal_taken`slot'  = ranking`r'playerappeal_choice_`slot' if round == `r'
        replace appeal_result`slot' = ranking`r'playerappeal_result_`slot' if round == `r'
    }
}

keep if inlist(treatment,1,2,4,5)
keep obsid paper_sample session round groupid id_in_group treatment IA rule probabilistic_rule first_stage_n first_stage_rank assigned_n ///
     priority_A priority_B priority_C true_rank_A true_rank_B true_rank_C ///
     fs_occupancy_A fs_occupancy_B fs_occupancy_C fs_worst_A fs_worst_B fs_worst_C ///
     appeal_school1 appeal_school2 appeal_school3 appeal_taken1 appeal_taken2 appeal_taken3 appeal_result1 appeal_result2 appeal_result3

reshape long appeal_school appeal_taken appeal_result, i(obsid) j(slot)
drop if appeal_school == ""

gen byte target_n = .
replace target_n = 1 if appeal_school == "A"
replace target_n = 2 if appeal_school == "B"
replace target_n = 3 if appeal_school == "C"
assert !missing(target_n)

gen byte target_rank = .
replace target_rank = true_rank_A if target_n == 1
replace target_rank = true_rank_B if target_n == 2
replace target_rank = true_rank_C if target_n == 3

gen byte strict_claim = 0
replace strict_claim = priority_A < fs_worst_A if target_n == 1 & fs_worst_A < .
replace strict_claim = priority_B < fs_worst_B if target_n == 2 & fs_worst_B < .
replace strict_claim = priority_C < fs_worst_C if target_n == 3 & fs_worst_C < .

gen byte gain_rank = first_stage_rank - target_rank
gen byte target_better = target_rank < first_stage_rank
gen byte appeal_success = appeal_taken == 1 & appeal_result == 1
gen byte appeal_useful = appeal_success & target_n == assigned_n & target_better

keep if paper_sample == 1
assert _N == 5725
compress
save "$DER/appeal_opportunities.dta", replace

/* One record for each eligible participant-period */
collapse (max) appealed_any=appeal_taken any_strict=strict_claim ///
         (count) n_opportunities=target_n ///
         (firstnm) session round groupid id_in_group treatment IA rule probabilistic_rule first_stage_rank, by(obsid)
assert _N == 2912
compress
save "$DER/appeal_rounds.dta", replace

restore

/* Sample audit */
tempname audit
postfile `audit' str52 sample long observations using "$DER/sample_audit.dta", replace
post `audit' ("Raw participant-period panel") (10220)
post `audit' ("Post-exit participant-period exclusions") (25)
post `audit' ("Final participant-period analysis sample") (10195)
post `audit' ("Final sample with personal controls") (10185)
post `audit' ("Complete seven-person market-rounds") (1435)
post `audit' ("Eligible participant-periods in appeal treatments") (2912)
post `audit' ("School-specific appeal opportunities") (5725)
postclose `audit'
use "$DER/sample_audit.dta", clear
export delimited using "$DER/sample_audit.csv", replace

clear
