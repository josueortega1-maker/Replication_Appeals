/**********************************************************************
 05_full_takeup.do

 Full-take-up counterfactual for Appendix E.

 The counterfactual holds submitted lists and first-stage assignments fixed
 and imposes the appeal strategy assumed in the model:
   - every procedurally available appeal that is truly preferred to the
     first-stage assignment is filed;
   - strict priority claims succeed with certainty;
   - under the probabilistic rule, all other filed appeals succeed
     independently with probability 0.1;
   - if several appeals succeed, the participant receives her most-preferred
     successful appeal according to induced true preferences.

 The probabilistic treatments are integrated exactly rather than simulated.
 Participant support has at most four final schools; market support is the
 Cartesian product of the seven participant supports.

 IMPORTANT DIAGNOSTIC
 The raw data should be checked against the oTree source before publication.
 In the supplied data, when more than one observed appeal succeeds, the final
 school follows the last successful appeal slot. The counterfactual below
 follows the rule stated in the manuscript (best successful appeal), because
 its purpose is to reproduce the theoretical benchmark.

 Outputs
   output/full_takeup/data
   output/full_takeup/figures
   output/full_takeup/tables
**********************************************************************/
version 18
clear
set more off
set linesize 255
set seed 20260721

capture program drop texcell_ft
program define texcell_ft, rclass
    syntax , B(real) SE(real) P(real) [DIGITS(integer 2)]
    local fmt "%9.`digits'f"
    local coef = strtrim(string(`b', "`fmt'"))
    local serr = strtrim(string(`se', "`fmt'"))
    local stars ""
    if `p' < 0.01 local stars "***"
    else if `p' < 0.05 local stars "**"
    else if `p' < 0.10 local stars "*"
    if "`stars'" != "" return local coef "\(`coef'^{`stars'}\)"
    else return local coef "\(`coef'\)"
    return local se "\((`serr')\)"
end

global FTOUT "$OUT/full_takeup"
global FTDER "$FTOUT/data"
global FTFIG "$FTOUT/figures"
global FTTAB "$FTOUT/tables"
capture mkdir "$FTOUT"
capture mkdir "$FTDER"
capture mkdir "$FTFIG"
capture mkdir "$FTTAB"

local da_no   "173 196 221"
local da_str  "31 73 125"
local da_prob "74 131 176"
local ia_no   "210 190 150"
local ia_str  "110 30 30"
local ia_prob "210 130 40"

/* Audit the resolution of observed multiple-success appeal rounds. */
use "$DER/appeal_opportunities.dta", clear
keep if appeal_result==1
bysort obsid: gen byte n_success_observed=_N
bysort obsid: egen byte best_success_rank=min(target_rank)
gen byte best_success_candidate=target_n if target_rank==best_success_rank
bysort obsid: egen byte best_success_target=max(best_success_candidate)
sort obsid slot
by obsid: gen byte last_success_target=target_n[_N]
by obsid: keep if _n==1
gen byte final_is_last_success=assigned_n==last_success_target
gen byte final_is_best_true_success=assigned_n==best_success_target
keep if n_success_observed>1
assert _N==68
assert final_is_last_success==1
quietly count if final_is_best_true_success==0
assert r(N)==58
save "$FTDER/multiple_success_diagnostic.dta", replace
export delimited using "$FTDER/multiple_success_diagnostic.csv", replace

/**********************************************************************
 A. Construct exact participant-level counterfactual support
**********************************************************************/
use "$DER/analysis_sample.dta", clear
keep obsid market_all session sessioncode participantid_in_session round groupid id_in_group ///
     treatment IA rule probabilistic_rule strict_rule no_appeals truthful age female risk_aversion ///
     choice1_n choice2_n choice3_n first_stage_n first_stage_rank first_stage_points ///
     true_rank_A true_rank_B true_rank_C priority_A priority_B priority_C
sort obsid
tempfile ftbase
save `ftbase'

/* Counts of truly beneficial appeal opportunities. */
use "$DER/appeal_opportunities.dta", clear
gen byte strict_better = strict_claim & target_better
collapse (sum) n_beneficial=target_better n_strict_better=strict_better, by(obsid)
tempfile ftcounts
save `ftcounts'

/* Best certain (strict-priority) successful appeal. */
use "$DER/appeal_opportunities.dta", clear
keep if target_better == 1 & strict_claim == 1
sort obsid target_rank target_n
by obsid: keep if _n == 1
keep obsid target_n target_rank
rename target_n strict_target_n
rename target_rank strict_target_rank
tempfile ftstrict
save `ftstrict'

/* Non-strict beneficial appeals, ordered by induced true preference. */
use "$DER/appeal_opportunities.dta", clear
keep if target_better == 1 & strict_claim == 0
sort obsid target_rank target_n
by obsid: gen byte nsj = _n
assert nsj <= 3
keep obsid nsj target_n target_rank
reshape wide target_n target_rank, i(obsid) j(nsj)
forvalues j = 1/3 {
    capture rename target_n`j' ns_target_n`j'
    capture rename target_rank`j' ns_target_rank`j'
}
tempfile ftnonstrict
save `ftnonstrict'

use `ftbase', clear
merge 1:1 obsid using `ftcounts', nogen
merge 1:1 obsid using `ftstrict', nogen
merge 1:1 obsid using `ftnonstrict', nogen
replace n_beneficial = 0 if missing(n_beneficial)
replace n_strict_better = 0 if missing(n_strict_better)
gen byte n_nonstrict_better = n_beneficial - n_strict_better
assert n_nonstrict_better >= 0

gen byte is_prob = inlist(treatment,1,4)
gen byte is_strict = inlist(treatment,2,5)
gen int n_patterns = cond(is_prob,2^n_nonstrict_better,1)
expand n_patterns, generate(ft_copy)
drop n_patterns
bysort obsid: gen byte pattern = _n - 1 if is_prob
replace pattern = 0 if !is_prob

forvalues j = 1/3 {
    gen byte bit`j' = mod(floor(pattern/(2^(`j'-1))),2) if is_prob
    replace bit`j' = 0 if missing(bit`j') | missing(ns_target_n`j')
}

gen double cf_prob = 1
forvalues j = 1/3 {
    replace cf_prob = cf_prob * cond(bit`j'==1,.1,.9) if is_prob & !missing(ns_target_n`j')
}

gen byte cf_assigned_n = first_stage_n
gen byte cf_assigned_rank = first_stage_rank

/* Strict claims are upheld with certainty under both appeal rules. */
replace cf_assigned_n = strict_target_n if (is_prob | is_strict) & !missing(strict_target_n)
replace cf_assigned_rank = strict_target_rank if (is_prob | is_strict) & !missing(strict_target_rank)

/* Non-strict claims are independent 0.1 lotteries under the probabilistic rule. */
forvalues j = 1/3 {
    replace cf_assigned_n = ns_target_n`j' if is_prob & bit`j'==1 & ///
        !missing(ns_target_rank`j') & ns_target_rank`j' < cf_assigned_rank
    replace cf_assigned_rank = ns_target_rank`j' if is_prob & bit`j'==1 & ///
        !missing(ns_target_rank`j') & ns_target_rank`j' < cf_assigned_rank
}

/* Collapse lottery patterns that imply the same final school. */
collapse (sum) cf_prob, by(obsid cf_assigned_n cf_assigned_rank)
merge m:1 obsid using `ftbase', assert(match) nogen
sort obsid cf_assigned_rank cf_assigned_n
bysort obsid: egen double cf_prob_sum = total(cf_prob)
assert abs(cf_prob_sum - 1) < 1e-10
drop cf_prob_sum

gen double cf_points = 20 - 5*cf_assigned_rank
gen double cf_direct_gain = cf_points - first_stage_points
compress
save "$FTDER/analysis_full_takeup_support.dta", replace

/* One observation per participant-period: exact expected outcome. */
preserve
gen double wrank = cf_prob*cf_assigned_rank
gen double wpoints = cf_prob*cf_points
gen double wdirect = cf_prob*cf_direct_gain
collapse (sum) cf_assigned_rank=wrank cf_points=wpoints cf_direct_gain=wdirect ///
         (firstnm) market_all session sessioncode participantid_in_session round groupid id_in_group ///
                   treatment IA rule probabilistic_rule strict_rule no_appeals truthful age female risk_aversion ///
                   choice1_n choice2_n choice3_n first_stage_n first_stage_rank first_stage_points, by(obsid)
assert _N == 10195
compress
save "$FTDER/analysis_full_takeup_expected.dta", replace
restore

/**********************************************************************
 B. Appeal opportunities and participant-rounds under full take-up
**********************************************************************/
use "$DER/appeal_opportunities.dta", clear
gen byte appeal_taken_cf = target_better
gen byte strict_better = strict_claim & target_better
gen double appeal_success_prob_cf = 0
replace appeal_success_prob_cf = 1 if strict_better
replace appeal_success_prob_cf = .1 if target_better & !strict_claim & probabilistic_rule
compress
save "$FTDER/appeal_opportunities_full_takeup.dta", replace

collapse (max) appealed_any_cf=appeal_taken_cf any_strict=strict_claim any_strict_better=strict_better ///
         (sum) n_beneficial=appeal_taken_cf n_strict_better=strict_better ///
         (count) n_opportunities=target_n ///
         (firstnm) session round groupid id_in_group treatment IA rule probabilistic_rule first_stage_rank, by(obsid)
gen byte n_nonstrict_better = n_beneficial - n_strict_better
gen double any_success_prob_cf = 0
replace any_success_prob_cf = 1 if any_strict_better
replace any_success_prob_cf = 1 - .9^n_nonstrict_better if !any_strict_better & probabilistic_rule & n_nonstrict_better>0
compress
save "$FTDER/appeal_rounds_full_takeup.dta", replace

/**********************************************************************
 C. Construct exact market-level counterfactual support
**********************************************************************/
/* Complete market list and market characteristics in wide form. */
use "$DER/analysis_sample.dta", clear
bysort market_all: gen byte market_size = _N
keep if market_size == 7

gen byte submitted_rank_A = cond(choice1_n==1,1,cond(choice2_n==1,2,3))
gen byte submitted_rank_B = cond(choice1_n==2,1,cond(choice2_n==2,2,3))
gen byte submitted_rank_C = cond(choice1_n==3,1,cond(choice2_n==3,2,3))

preserve
keep market_all
bysort market_all: keep if _n==1
tempfile complete_markets
save `complete_markets'
restore

keep market_all session round groupid treatment IA rule id_in_group ///
     submitted_rank_A submitted_rank_B submitted_rank_C ///
     true_rank_A true_rank_B true_rank_C priority_A priority_B priority_C
reshape wide submitted_rank_A submitted_rank_B submitted_rank_C ///
             true_rank_A true_rank_B true_rank_C priority_A priority_B priority_C, ///
             i(market_all session round groupid treatment IA rule) j(id_in_group)
tempfile market_traits
save `market_traits'

/* One support file for each participant type. */
forvalues i = 1/7 {
    use "$FTDER/analysis_full_takeup_support.dta", clear
    merge m:1 market_all using `complete_markets', keep(match) nogen
    keep if id_in_group == `i'
    keep market_all cf_assigned_n cf_prob
    rename cf_assigned_n cf_assigned_n`i'
    rename cf_prob cf_prob`i'
    save "$FTDER/_ft_role`i'.dta", replace
}

use "$FTDER/_ft_role1.dta", clear
forvalues i = 2/7 {
    joinby market_all using "$FTDER/_ft_role`i'.dta"
}

gen double cf_prob = 1
forvalues i = 1/7 {
    replace cf_prob = cf_prob*cf_prob`i'
    drop cf_prob`i'
}
merge m:1 market_all using `market_traits', assert(match) nogen

/* Final submitted and induced ranks. */
forvalues i = 1/7 {
    gen byte final_true_rank`i' = 4
    replace final_true_rank`i' = true_rank_A`i' if cf_assigned_n`i'==1
    replace final_true_rank`i' = true_rank_B`i' if cf_assigned_n`i'==2
    replace final_true_rank`i' = true_rank_C`i' if cf_assigned_n`i'==3

    gen byte final_sub_rank`i' = 4
    replace final_sub_rank`i' = submitted_rank_A`i' if cf_assigned_n`i'==1
    replace final_sub_rank`i' = submitted_rank_B`i' if cf_assigned_n`i'==2
    replace final_sub_rank`i' = submitted_rank_C`i' if cf_assigned_n`i'==3
}

local bp_sub_vars ""
local waste_sub_vars ""
local bp_true_vars ""
local waste_true_vars ""

foreach S in A B C {
    if "`S'"=="A" local sn=1
    if "`S'"=="B" local sn=2
    if "`S'"=="C" local sn=3
    gen byte occupancy_`S' = 0
    forvalues i = 1/7 {
        replace occupancy_`S' = occupancy_`S' + (cf_assigned_n`i'==`sn')
        gen byte occpri_`S'`i' = cond(cf_assigned_n`i'==`sn',priority_`S'`i',.)
    }
    egen byte worst_`S' = rowmax(occpri_`S'1-occpri_`S'7)
    drop occpri_`S'1-occpri_`S'7

    forvalues i = 1/7 {
        gen byte bp_sub_`S'`i' = submitted_rank_`S'`i' < final_sub_rank`i' & ///
            worst_`S' < . & priority_`S'`i' < worst_`S'
        gen byte waste_sub_`S'`i' = submitted_rank_`S'`i' < final_sub_rank`i' & occupancy_`S' < 2
        gen byte bp_true_`S'`i' = true_rank_`S'`i' < final_true_rank`i' & ///
            worst_`S' < . & priority_`S'`i' < worst_`S'
        gen byte waste_true_`S'`i' = true_rank_`S'`i' < final_true_rank`i' & occupancy_`S' < 2
        local bp_sub_vars "`bp_sub_vars' bp_sub_`S'`i'"
        local waste_sub_vars "`waste_sub_vars' waste_sub_`S'`i'"
        local bp_true_vars "`bp_true_vars' bp_true_`S'`i'"
        local waste_true_vars "`waste_true_vars' waste_true_`S'`i'"
    }
}

egen byte strict_bp_sub = rowtotal(`bp_sub_vars')
egen byte waste_sub = rowtotal(`waste_sub_vars')
egen byte strict_bp_true = rowtotal(`bp_true_vars')
egen byte waste_true = rowtotal(`waste_true_vars')
gen byte stable_sub = strict_bp_sub==0 & waste_sub==0
gen byte stable_true = strict_bp_true==0 & waste_true==0

gen byte weak_pareto_da = final_true_rank1<=2 & final_true_rank2<=2 & final_true_rank3<=4 & ///
                          final_true_rank4<=2 & final_true_rank5<=3 & final_true_rank6<=3 & final_true_rank7<=3
gen byte strict_pareto_da = weak_pareto_da & ///
    (final_true_rank1<2 | final_true_rank2<2 | final_true_rank3<4 | final_true_rank4<2 | ///
     final_true_rank5<3 | final_true_rank6<3 | final_true_rank7<3)

keep market_all session round groupid treatment IA rule cf_prob strict_bp_sub waste_sub stable_sub ///
     strict_bp_true waste_true stable_true weak_pareto_da strict_pareto_da
sort market_all
bysort market_all: egen double market_prob_sum = total(cf_prob)
assert abs(market_prob_sum-1) < 1e-10
drop market_prob_sum
compress
save "$FTDER/market_rounds_full_takeup_support.dta", replace

/* One record per market: exact expected outcome/probability. */
gen double w_bp_sub = cf_prob*strict_bp_sub
gen double w_waste_sub = cf_prob*waste_sub
gen double w_stable_sub = cf_prob*stable_sub
gen double w_bp_true = cf_prob*strict_bp_true
gen double w_waste_true = cf_prob*waste_true
gen double w_stable_true = cf_prob*stable_true
gen double w_weak = cf_prob*weak_pareto_da
gen double w_strict = cf_prob*strict_pareto_da
collapse (sum) strict_bp_sub=w_bp_sub waste_sub=w_waste_sub stable_sub=w_stable_sub ///
               strict_bp_true=w_bp_true waste_true=w_waste_true stable_true=w_stable_true ///
               weak_pareto_da=w_weak strict_pareto_da=w_strict ///
         (firstnm) session round groupid treatment IA rule, by(market_all)
assert _N == 1435
compress
save "$FTDER/market_rounds_full_takeup_expected.dta", replace
forvalues i=1/7 {
    capture erase "$FTDER/_ft_role`i'.dta"
}

/**********************************************************************
 D. Outputs corresponding to every main-text figure and table
**********************************************************************/
/* Table 1, Figure 1, and Table 2 are unchanged because reports are fixed. */
capture copy "$TAB/table1_uphold_rules.tex" "$FTTAB/table1_uphold_rules_full_takeup.tex", replace
capture copy "$FIG/figure1_truth_telling.pdf" "$FTFIG/figure1_truth_telling_full_takeup.pdf", replace
capture copy "$FIG/figure1_truth_telling.png" "$FTFIG/figure1_truth_telling_full_takeup.png", replace
capture copy "$TAB/table2_truth_telling.tex" "$FTTAB/table2_truth_telling_full_takeup.tex", replace
capture copy "$DER/table2_truth_telling_estimates.dta" "$FTDER/table2_truth_telling_estimates.dta", replace
capture copy "$DER/table2_truth_telling_estimates.csv" "$FTDER/table2_truth_telling_estimates.csv", replace

/**********************************************************************
 Figure 2: appeal take-up and success under the theoretical strategy
**********************************************************************/
use "$FTDER/appeal_rounds_full_takeup.dta", clear
tempfile fig2data
postfile ftfig2 byte treatment double take_mean take_se take_lo take_hi succ_mean succ_se succ_lo succ_hi using `fig2data', replace
foreach t in 2 1 5 4 {
    quietly regress appealed_any_cf if treatment==`t', vce(cluster session)
    local mt=_b[_cons]
    local st=_se[_cons]
    quietly regress any_success_prob_cf if treatment==`t' & appealed_any_cf==1, vce(cluster session)
    local ms=_b[_cons]
    local ss=_se[_cons]
    post ftfig2 (`t') (`mt') (`st') (`mt'-1.96*`st') (`mt'+1.96*`st') ///
        (`ms') (`ss') (`ms'-1.96*`ss') (`ms'+1.96*`ss')
}
postclose ftfig2
use `fig2data', clear
gen byte xpos=cond(treatment==2,1,cond(treatment==1,2,cond(treatment==5,4,5)))
gen double x_take=xpos-.18
gen double x_succ=xpos+.18

twoway ///
    (bar take_mean x_take if treatment==2, barwidth(.34) color("`da_str'")) ///
    (bar succ_mean x_succ if treatment==2, barwidth(.34) color("173 196 221")) ///
    (bar take_mean x_take if treatment==1, barwidth(.34) color("`da_prob'")) ///
    (bar succ_mean x_succ if treatment==1, barwidth(.34) color("190 210 230")) ///
    (bar take_mean x_take if treatment==5, barwidth(.34) color("`ia_str'")) ///
    (bar succ_mean x_succ if treatment==5, barwidth(.34) color("195 135 135")) ///
    (bar take_mean x_take if treatment==4, barwidth(.34) color("`ia_prob'")) ///
    (bar succ_mean x_succ if treatment==4, barwidth(.34) color("235 190 145")) ///
    (rcap take_hi take_lo x_take, lcolor(black)) ///
    (rcap succ_hi succ_lo x_succ, lcolor(black)) ///
    (scatter take_hi x_take, msymbol(none) mlabel(take_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2)) ///
    (scatter succ_hi x_succ, msymbol(none) mlabel(succ_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2)), ///
    xline(3, lcolor(gs12)) ///
    xlabel(1 `" "DA" "Strict" "' 2 `" "DA" "Probabilistic" "' 4 `" "IA" "Strict" "' 5 `" "IA" "Probabilistic" "', noticks labsize(small)) ///
    ylabel(0(.2)1, angle(horizontal) glcolor(gs14)) yscale(range(0 1.06)) ///
    xtitle("") ytitle("Share") legend(order(1 "Take-up" 2 "Success") cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)
graph export "$FTFIG/figure2_appeal_takeup_success_full_takeup.pdf", replace
graph export "$FTFIG/figure2_appeal_takeup_success_full_takeup.png", width(2400) replace

/**********************************************************************
 Table 3: deterministic correlates of theoretical appeal filing
**********************************************************************/
tempfile table3data
postfile ftt3 byte row col double estimate se pvalue long N double r2 using `table3data', replace
use "$FTDER/appeal_rounds_full_takeup.dta", clear
quietly regress appealed_any_cf ib2.treatment ib1.first_stage_rank any_strict n_opportunities i.round, vce(cluster session)
local NN=e(N)
local RR=e(r2)
foreach z in "1 1.treatment" "2 5.treatment" "3 4.treatment" "4 2.first_stage_rank" "5 3.first_stage_rank" "6 4.first_stage_rank" "7 any_strict" "8 n_opportunities" {
    tokenize `z'
    quietly lincom `2'
    post ftt3 (`1') (1) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
}
use "$FTDER/appeal_opportunities_full_takeup.dta", clear
quietly regress appeal_taken_cf ib2.treatment ib1.first_stage_rank strict_claim ib1.target_rank i.round, vce(cluster session)
local NN=e(N)
local RR=e(r2)
foreach z in "1 1.treatment" "2 5.treatment" "3 4.treatment" "4 2.first_stage_rank" "5 3.first_stage_rank" "6 4.first_stage_rank" "7 strict_claim" {
    tokenize `z'
    quietly lincom `2'
    post ftt3 (`1') (2) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
}
quietly lincom 2.target_rank
post ftt3 (9) (2) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
quietly lincom 3.target_rank
post ftt3 (10) (2) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
postclose ftt3
use `table3data', clear
save "$FTDER/table3_appeal_use_estimates_full_takeup.dta", replace
export delimited using "$FTDER/table3_appeal_use_estimates_full_takeup.csv", replace

local rowlabel1 "DA, probabilistic appeals"
local rowlabel2 "IA, strict appeals"
local rowlabel3 "IA, probabilistic appeals"
local rowlabel4 "First-stage assignment: second choice"
local rowlabel5 "First-stage assignment: third choice"
local rowlabel6 "First-stage assignment: unassigned"
local rowlabel7 "Strict priority claim"
local rowlabel8 "Number of appeal opportunities"
local rowlabel9 "Appeal target: second choice"
local rowlabel10 "Appeal target: third choice"

tempname tex3
file open `tex3' using "$FTTAB/table3_appeal_use_full_takeup.tex", write replace
file write `tex3' "\begin{table}[htbp]" _n "\centering" _n
file write `tex3' "\caption{Determinants of appeal filing under full take-up}" _n
file write `tex3' "\begin{threeparttable}" _n "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcc @{}}" _n
file write `tex3' "\toprule" _n "& Any appeal & Appeal opportunity taken \\" _n "\midrule" _n
forvalues r=1/10 {
    local c1 "\(\cdot\)"
    local s1 ""
    local c2 "\(\cdot\)"
    local s2 ""
    quietly count if row==`r' & col==1
    if r(N) {
        quietly summarize estimate if row==`r' & col==1, meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & col==1, meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & col==1, meanonly
        local pp=r(mean)
        quietly texcell_ft, b(`bb') se(`ss') p(`pp')
        local c1 "`r(coef)'"
        local s1 "`r(se)'"
    }
    quietly count if row==`r' & col==2
    if r(N) {
        quietly summarize estimate if row==`r' & col==2, meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & col==2, meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & col==2, meanonly
        local pp=r(mean)
        quietly texcell_ft, b(`bb') se(`ss') p(`pp')
        local c2 "`r(coef)'"
        local s2 "`r(se)'"
    }
    file write `tex3' "`rowlabel`r'' & `c1' & `c2' \\" _n "& `s1' & `s2' \\" _n
}
file write `tex3' "\midrule" _n "Round fixed effects & Yes & Yes \\" _n
file write `tex3' "Observations & 2{,}912 & 5{,}725 \\" _n "Matching groups & 41 & 41 \\" _n
file write `tex3' "\bottomrule" _n "\end{tabular*}" _n
file write `tex3' "\begin{tablenotes}[flushleft]\footnotesize\item Notes. These regressions are mechanical diagnostics, not behavioral estimates: filing is imposed whenever an appealable school is truly preferred to the first-stage assignment. Standard errors are clustered at the matching-group level.\end{tablenotes}" _n
file write `tex3' "\end{threeparttable}" _n "\end{table}" _n
file close `tex3'

/**********************************************************************
 Figure 3 and Table 4: assigned rank
**********************************************************************/
use "$FTDER/analysis_full_takeup_expected.dta", clear
tempfile fig3data
postfile ftfig3 byte treatment double rank_mean rank_se rank_lo rank_hi using `fig3data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress cf_assigned_rank if treatment==`t', vce(cluster session)
    local m=_b[_cons]
    local s=_se[_cons]
    post ftfig3 (`t') (`m') (`s') (`m'-1.96*`s') (`m'+1.96*`s')
}
postclose ftfig3
use `fig3data', clear
gen byte xpos=cond(treatment==3,1,cond(treatment==2,2,cond(treatment==1,3,cond(treatment==6,5,cond(treatment==5,6,7)))))
local xlabel6 1 `" "DA" "No appeals" "' 2 `" "DA" "Strict" "' 3 `" "DA" "Probabilistic" "' 5 `" "IA" "No appeals" "' 6 `" "IA" "Strict" "' 7 `" "IA" "Probabilistic" "'
twoway ///
    (bar rank_mean xpos if treatment==3, barwidth(.70) color("`da_no'")) ///
    (bar rank_mean xpos if treatment==2, barwidth(.70) color("`da_str'")) ///
    (bar rank_mean xpos if treatment==1, barwidth(.70) color("`da_prob'")) ///
    (bar rank_mean xpos if treatment==6, barwidth(.70) color("`ia_no'")) ///
    (bar rank_mean xpos if treatment==5, barwidth(.70) color("`ia_str'")) ///
    (bar rank_mean xpos if treatment==4, barwidth(.70) color("`ia_prob'")) ///
    (rcap rank_hi rank_lo xpos, lcolor(black)) ///
    (scatter rank_hi xpos, msymbol(none) mlabel(rank_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2)), ///
    xline(4, lcolor(gs12)) xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(1(.5)4, angle(horizontal) glcolor(gs14)) yscale(range(1 4.10)) ///
    xtitle("") ytitle("Expected average rank") legend(off) ///
    graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)
graph export "$FTFIG/figure3_rank_welfare_full_takeup.pdf", replace
graph export "$FTFIG/figure3_rank_welfare_full_takeup.png", width(2400) replace

use "$FTDER/analysis_full_takeup_support.dta", clear
tempfile table4data
postfile ftt4 byte row spec double estimate se pvalue long N using `table4data', replace
forvalues spec=1/4 {
    if `spec'==1 quietly ologit cf_assigned_rank i.treatment [pw=cf_prob], vce(cluster session)
    if `spec'==2 quietly ologit cf_assigned_rank i.treatment i.round [pw=cf_prob], vce(cluster session)
    if `spec'==3 quietly ologit cf_assigned_rank i.treatment i.round i.id_in_group [pw=cf_prob], vce(cluster session)
    if `spec'==4 quietly ologit cf_assigned_rank i.treatment i.round i.id_in_group age female risk_aversion [pw=cf_prob], vce(cluster session)
    quietly summarize cf_prob if e(sample), meanonly
    local NN=round(r(sum))
    quietly margins treatment, expression(predict(outcome(1))*1 + predict(outcome(2))*2 + predict(outcome(3))*3 + predict(outcome(4))*4) post
    quietly lincom 5.treatment-6.treatment
    post ftt4 (1) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment-6.treatment
    post ftt4 (2) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment-3.treatment
    post ftt4 (3) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment-3.treatment
    post ftt4 (4) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom (2.treatment-5.treatment)-(3.treatment-6.treatment)
    post ftt4 (5) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom (1.treatment-4.treatment)-(3.treatment-6.treatment)
    post ftt4 (6) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose ftt4
use `table4data', clear
save "$FTDER/table4_rank_estimates_full_takeup.dta", replace
export delimited using "$FTDER/table4_rank_estimates_full_takeup.csv", replace

local rowlabel1 "IA strict"
local rowlabel2 "IA probabilistic"
local rowlabel3 "DA strict"
local rowlabel4 "DA probabilistic"
local rowlabel5 "Strict appeals"
local rowlabel6 "Probabilistic appeals"
tempname tex4
file open `tex4' using "$FTTAB/table4_assigned_rank_full_takeup.tex", write replace
file write `tex4' "\begin{table}[htbp]\centering\caption{Impact of appeals on assigned rank under full take-up}" _n
file write `tex4' "\begin{threeparttable}\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcccc @{}}\toprule" _n
file write `tex4' "& (1) & (2) & (3) & (4) \\ \midrule" _n
forvalues r=1/6 {
    if `r'==3 file write `tex4' "\addlinespace\multicolumn{5}{l}{\textbf{DA treatments}} \\" _n
    if `r'==5 file write `tex4' "\addlinespace\multicolumn{5}{l}{\textbf{Increase in the DA--IA rank gap}} \\" _n
    local line ""
    local seline ""
    forvalues s=1/4 {
        quietly summarize estimate if row==`r' & spec==`s', meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & spec==`s', meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & spec==`s', meanonly
        local pp=r(mean)
        quietly texcell_ft, b(`bb') se(`ss') p(`pp')
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `tex4' "`rowlabel`r''`line' \\" _n "`seline' \\" _n
}
file write `tex4' "\midrule Round effects & No & Yes & Yes & Yes \\" _n
file write `tex4' "Participant-type effects & No & No & Yes & Yes \\" _n
file write `tex4' "Demographics + risk att. & No & No & No & Yes \\" _n
file write `tex4' "\bottomrule\end{tabular*}" _n
file write `tex4' "\begin{tablenotes}[flushleft]\footnotesize\item Notes. The probabilistic appeal outcomes are integrated exactly. Entries are adjusted differences in expected assigned rank from probability-weighted ordered logit models; lower values are better. Standard errors are clustered at the matching-group level.\end{tablenotes}" _n
file write `tex4' "\end{threeparttable}\end{table}" _n
file close `tex4'

/**********************************************************************
 Table 5: welfare decomposition
**********************************************************************/
use "$FTDER/analysis_full_takeup_expected.dta", clear
tempfile table5data
postfile ftt5 byte treatment double total total_se total_p reporting reporting_se reporting_p direct direct_se direct_p using `table5data', replace
foreach pair in "2 3" "1 3" "5 6" "4 6" {
    tokenize `pair'
    local t=`1'
    local b=`2'
    quietly regress cf_points i.treatment if inlist(treatment,`t',`b'), vce(cluster session)
    quietly margins treatment, post
    quietly lincom `t'.treatment-`b'.treatment
    local total=r(estimate)
    local total_se=r(se)
    local total_p=r(p)

    use "$FTDER/analysis_full_takeup_expected.dta", clear
    quietly regress first_stage_points i.treatment if inlist(treatment,`t',`b'), vce(cluster session)
    quietly margins treatment, post
    quietly lincom `t'.treatment-`b'.treatment
    local reporting=r(estimate)
    local reporting_se=r(se)
    local reporting_p=r(p)

    use "$FTDER/analysis_full_takeup_expected.dta", clear
    quietly regress cf_direct_gain if treatment==`t', vce(cluster session)
    local direct=_b[_cons]
    local direct_se=_se[_cons]
    local direct_p=.
    if `direct_se'>0 local direct_p=2*ttail(e(df_r),abs(`direct'/`direct_se'))
    post ftt5 (`t') (`total') (`total_se') (`total_p') (`reporting') (`reporting_se') (`reporting_p') (`direct') (`direct_se') (`direct_p')
}
postclose ftt5
use `table5data', clear
save "$FTDER/table5_welfare_decomposition_full_takeup.dta", replace
export delimited using "$FTDER/table5_welfare_decomposition_full_takeup.csv", replace

local rowlabel2 "DA, strict appeals"
local rowlabel1 "DA, probabilistic appeals"
local rowlabel5 "IA, strict appeals"
local rowlabel4 "IA, probabilistic appeals"
tempname tex5
file open `tex5' using "$FTTAB/table5_welfare_decomposition_full_takeup.tex", write replace
file write `tex5' "\begin{table}[htbp]\centering\caption{Welfare decomposition under full take-up}" _n
file write `tex5' "\begin{threeparttable}\begin{tabular}{lccc}\toprule" _n
file write `tex5' "Treatment & Total effect & Reporting channel & Direct appeal channel \\ \midrule" _n
foreach t in 2 1 5 4 {
    local line ""
    local seline ""
    foreach v in total reporting direct {
        quietly summarize `v' if treatment==`t', meanonly
        local bb=r(mean)
        quietly summarize `v'_se if treatment==`t', meanonly
        local ss=r(mean)
        quietly summarize `v'_p if treatment==`t', meanonly
        local pp=r(mean)
        quietly texcell_ft, b(`bb') se(`ss') p(`pp') digits(2)
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `tex5' "`rowlabel`t''`line' \\" _n "`seline' \\" _n
}
file write `tex5' "\bottomrule\end{tabular}" _n
file write `tex5' "\begin{tablenotes}[flushleft]\footnotesize\item Notes. Outcomes are expected experimental points. Submitted lists and first-stage assignments are held fixed. Standard errors are clustered at the matching-group level.\end{tablenotes}" _n
file write `tex5' "\end{threeparttable}\end{table}" _n
file close `tex5'

/**********************************************************************
 Pareto-dominance statistics
**********************************************************************/
use "$FTDER/market_rounds_full_takeup_expected.dta", clear
gen double weak_n=weak_pareto_da
gen double strict_n=strict_pareto_da
collapse (count) markets=market_all (sum) weak_n strict_n, by(treatment)
gen double weak_share=weak_n/markets
gen double strict_share=strict_n/markets
save "$FTDER/pareto_dominance_summary_full_takeup.dta", replace
export delimited using "$FTDER/pareto_dominance_summary_full_takeup.csv", replace

tempname texp
file open `texp' using "$FTTAB/table_pareto_dominance_full_takeup.tex", write replace
file write `texp' "\begin{table}[htbp]\centering\caption{Counterfactual assignments relative to truthful DA}" _n
file write `texp' "\begin{tabular}{lccc}\toprule Treatment & Markets & Weak dominance & Strict dominance \\ \midrule" _n
local lab3 "DA, no appeals"
local lab2 "DA, strict appeals"
local lab1 "DA, probabilistic appeals"
local lab6 "IA, no appeals"
local lab5 "IA, strict appeals"
local lab4 "IA, probabilistic appeals"
foreach t in 3 2 1 6 5 4 {
    quietly summarize markets if treatment==`t', meanonly
    local n=r(mean)
    quietly summarize weak_n if treatment==`t', meanonly
    local nw=r(mean)
    quietly summarize weak_share if treatment==`t', meanonly
    local sw=100*r(mean)
    quietly summarize strict_n if treatment==`t', meanonly
    local ns=r(mean)
    quietly summarize strict_share if treatment==`t', meanonly
    local ss=100*r(mean)
    local nstr : display %9.0f `n'
    local nwstr : display %9.1f `nw'
    local swstr : display %5.2f `sw'
    local nsstr : display %9.1f `ns'
    local ssstr : display %5.2f `ss'
    file write `texp' "`lab`t'' & `nstr' & `nwstr' (`swstr'\%) & `nsstr' (`ssstr'\%) \\" _n
}
file write `texp' "\bottomrule\end{tabular}" _n
file write `texp' "\begin{flushleft}\footnotesize Notes. Counts can be fractional because probabilistic appeal outcomes are integrated exactly.\end{flushleft}\end{table}" _n
file close `texp'

/**********************************************************************
 Figure 4 and Table 6: stability
**********************************************************************/
use "$FTDER/market_rounds_full_takeup_expected.dta", clear
collapse (mean) stable_sub stable_true, by(treatment session)
tempfile fig4data
postfile ftfig4 byte treatment double sub_mean sub_se sub_lo sub_hi true_mean true_se true_lo true_hi using `fig4data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress stable_sub if treatment==`t'
    local m1=_b[_cons]
    local s1=_se[_cons]
    quietly regress stable_true if treatment==`t'
    local m2=_b[_cons]
    local s2=_se[_cons]
    post ftfig4 (`t') (`m1') (`s1') (`m1'-1.96*`s1') (`m1'+1.96*`s1') ///
        (`m2') (`s2') (`m2'-1.96*`s2') (`m2'+1.96*`s2')
}
postclose ftfig4
use `fig4data', clear
gen byte xpos=cond(treatment==3,1,cond(treatment==2,2,cond(treatment==1,3,cond(treatment==6,5,cond(treatment==5,6,7)))))
gen double x_sub=xpos-.18
gen double x_true=xpos+.18
twoway ///
    (bar sub_mean x_sub, barwidth(.34) color("31 119 180")) ///
    (bar true_mean x_true, barwidth(.34) color("255 127 14")) ///
    (rcap sub_hi sub_lo x_sub, lcolor(black)) ///
    (rcap true_hi true_lo x_true, lcolor(black)) ///
    (scatter sub_hi x_sub, msymbol(none) mlabel(sub_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2)) ///
    (scatter true_hi x_true, msymbol(none) mlabel(true_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2)), ///
    xline(4, lcolor(gs12)) xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(0(.2)1, angle(horizontal) glcolor(gs14)) yscale(range(0 1.08)) ///
    xtitle("") ytitle("Expected share of stable market-rounds") ///
    legend(order(1 "Submitted preferences" 2 "Induced preferences") cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)
graph export "$FTFIG/figure4_stability_full_takeup.pdf", replace
graph export "$FTFIG/figure4_stability_full_takeup.png", width(2400) replace

use "$FTDER/market_rounds_full_takeup_expected.dta", clear
tempfile table6data
postfile ftt6 byte row col double estimate se pvalue long N using `table6data', replace
local outcome1 strict_bp_sub
local outcome2 waste_sub
local outcome3 stable_sub
forvalues c=1/3 {
    quietly regress `outcome`c'' ib3.treatment i.round, vce(cluster session)
    local NN=e(N)
    quietly lincom 5.treatment-6.treatment
    post ftt6 (1) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment-6.treatment
    post ftt6 (2) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment
    post ftt6 (3) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment
    post ftt6 (4) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose ftt6
use `table6data', clear
save "$FTDER/table6_stability_estimates_full_takeup.dta", replace
export delimited using "$FTDER/table6_stability_estimates_full_takeup.csv", replace
local rowlabel1 "IA strict"
local rowlabel2 "IA probabilistic"
local rowlabel3 "DA strict"
local rowlabel4 "DA probabilistic"
tempname tex6
file open `tex6' using "$FTTAB/table6_stability_full_takeup.tex", write replace
file write `tex6' "\begin{table}[htbp]\centering\caption{Impact of appeals on stability under full take-up}" _n
file write `tex6' "\begin{threeparttable}\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lccc @{}}\toprule" _n
file write `tex6' "& Strict blocking pairs & Wasted-seat claims & Stable market-round \\ \midrule" _n
forvalues r=1/4 {
    local line ""
    local seline ""
    forvalues c=1/3 {
        quietly summarize estimate if row==`r' & col==`c', meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & col==`c', meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & col==`c', meanonly
        local pp=r(mean)
        quietly texcell_ft, b(`bb') se(`ss') p(`pp')
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `tex6' "`rowlabel`r''`line' \\" _n "`seline' \\" _n
}
file write `tex6' "\midrule Round effects & Yes & Yes & Yes \\" _n
file write `tex6' "Observations & 1{,}435 & 1{,}435 & 1{,}435 \\" _n
file write `tex6' "\bottomrule\end{tabular*}" _n
file write `tex6' "\begin{tablenotes}[flushleft]\footnotesize\item Notes. Outcomes are exact expectations over the probabilistic appeal lotteries. Standard errors are clustered at the matching-group level. Stability is evaluated against submitted preferences.\end{tablenotes}" _n
file write `tex6' "\end{threeparttable}\end{table}" _n
file close `tex6'

/**********************************************************************
 Figure 5: normalized comparison
**********************************************************************/
use "$FTDER/analysis_full_takeup_expected.dta", clear
collapse (mean) truth=truthful rank=cf_assigned_rank, by(treatment)
gen double rank_eff=4-rank
tempfile partmetrics
save `partmetrics'
use "$FTDER/market_rounds_full_takeup_expected.dta", clear
collapse (mean) stable_sub, by(treatment session)
collapse (mean) procedural_stability=stable_sub, by(treatment)
merge 1:1 treatment using `partmetrics', nogen
quietly summarize truth, meanonly
replace truth=truth/r(max)
quietly summarize rank_eff, meanonly
replace rank_eff=rank_eff/r(max)
quietly summarize procedural_stability, meanonly
replace procedural_stability=procedural_stability/r(max)
expand 4
bysort treatment: gen byte vertex=_n
gen double metric=cond(inlist(vertex,1,4),truth,cond(vertex==2,rank_eff,procedural_stability))
gen double angle=cond(inlist(vertex,1,4),_pi/2,cond(vertex==2,-_pi/6,7*_pi/6))
gen double x=metric*cos(angle)
gen double y=metric*sin(angle)
gen byte grid=.
gen int plotid=10+treatment
tempfile radar
save `radar'
clear
set obs 16
gen byte grid=ceil(_n/4)
bysort grid: gen byte vertex=_n
gen double metric=.25*grid
gen double angle=cond(inlist(vertex,1,4),_pi/2,cond(vertex==2,-_pi/6,7*_pi/6))
gen double x=metric*cos(angle)
gen double y=metric*sin(angle)
gen byte treatment=.
gen int plotid=grid
append using `radar'
sort plotid vertex
twoway ///
    (line y x if grid==1, lcolor(gs14)) (line y x if grid==2, lcolor(gs14)) ///
    (line y x if grid==3, lcolor(gs14)) (line y x if grid==4, lcolor(gs12)) ///
    (connected y x if treatment==3, lcolor("`da_no'") mcolor("`da_no'") msymbol(O)) ///
    (connected y x if treatment==2, lcolor("`da_str'") mcolor("`da_str'") msymbol(O)) ///
    (connected y x if treatment==1, lcolor("`da_prob'") mcolor("`da_prob'") msymbol(O)) ///
    (connected y x if treatment==6, lcolor("`ia_no'") mcolor("`ia_no'") msymbol(O)) ///
    (connected y x if treatment==5, lcolor("`ia_str'") mcolor("`ia_str'") msymbol(O)) ///
    (connected y x if treatment==4, lcolor("`ia_prob'") mcolor("`ia_prob'") msymbol(O)), ///
    text(1.12 0 "Truth-telling", size(small)) text(-.64 1.02 "Rank-efficiency", size(small)) ///
    text(-.64 -1.02 "Procedural stability", size(small)) ///
    xscale(range(-1.20 1.20) off) yscale(range(-1.05 1.22) off) xlabel(, nogrid) ylabel(, nogrid) aspect(1) ///
    legend(order(5 "DA, no appeals" 6 "DA, strict" 7 "DA, probabilistic" 8 "IA, no appeals" 9 "IA, strict" 10 "IA, probabilistic") cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(small)) bgcolor(white)
graph export "$FTFIG/figure5_normalized_comparison_full_takeup.pdf", replace
graph export "$FTFIG/figure5_normalized_comparison_full_takeup.png", width(2400) replace

/**********************************************************************
 E. Compact appendix summary table: observed versus full take-up
**********************************************************************/
/* Observed treatment means. */
use "$DER/analysis_sample.dta", clear
collapse (mean) observed_rank=assigned_rank, by(treatment)
tempfile obsrank
save `obsrank'
use "$DER/market_rounds.dta", clear
collapse (mean) observed_bp=strict_bp_sub observed_pareto=strict_pareto_da, by(treatment)
tempfile obsmkt
save `obsmkt'
use "$DER/market_rounds.dta", clear
collapse (mean) stable_sub, by(treatment session)
collapse (mean) observed_stable=stable_sub, by(treatment)
merge 1:1 treatment using `obsrank', nogen
merge 1:1 treatment using `obsmkt', nogen
tempfile observed
save `observed'

/* Full-take-up treatment means. */
use "$FTDER/analysis_full_takeup_expected.dta", clear
collapse (mean) full_rank=cf_assigned_rank, by(treatment)
tempfile fullrank
save `fullrank'
use "$FTDER/market_rounds_full_takeup_expected.dta", clear
collapse (mean) full_bp=strict_bp_sub full_pareto=strict_pareto_da, by(treatment)
tempfile fullmkt
save `fullmkt'
use "$FTDER/market_rounds_full_takeup_expected.dta", clear
collapse (mean) stable_sub, by(treatment session)
collapse (mean) full_stable=stable_sub, by(treatment)
merge 1:1 treatment using `fullrank', nogen
merge 1:1 treatment using `fullmkt', nogen
merge 1:1 treatment using `observed', nogen
keep if inlist(treatment,1,2,4,5)
sort treatment
save "$FTDER/table_full_takeup_summary.dta", replace
export delimited using "$FTDER/table_full_takeup_summary.csv", replace

local lab2 "DA, strict"
local lab1 "DA, probabilistic"
local lab5 "IA, strict"
local lab4 "IA, probabilistic"
tempname texs
file open `texs' using "$FTTAB/table_full_takeup_summary.tex", write replace
file write `texs' "\begin{table}[htbp]\centering\caption{Observed outcomes and the full-take-up counterfactual}\label{tab:full-takeup}" _n
file write `texs' "\resizebox{\textwidth}{!}{\begin{tabular}{lcccccccc}\toprule" _n
file write `texs' "& \multicolumn{2}{c}{Average rank} & \multicolumn{2}{c}{Strict blocking pairs} & \multicolumn{2}{c}{Stable share} & \multicolumn{2}{c}{Strictly dominates DA} \\" _n
file write `texs' "Treatment & Obs. & Full & Obs. & Full & Obs. & Full & Obs. & Full \\ \midrule" _n
foreach t in 2 1 5 4 {
    quietly summarize observed_rank if treatment==`t', meanonly
    local a: display %4.2f r(mean)
    quietly summarize full_rank if treatment==`t', meanonly
    local b: display %4.2f r(mean)
    quietly summarize observed_bp if treatment==`t', meanonly
    local c: display %4.2f r(mean)
    quietly summarize full_bp if treatment==`t', meanonly
    local d: display %4.2f r(mean)
    quietly summarize observed_stable if treatment==`t', meanonly
    local e: display %4.2f r(mean)
    quietly summarize full_stable if treatment==`t', meanonly
    local f: display %4.2f r(mean)
    quietly summarize observed_pareto if treatment==`t', meanonly
    local g: display %4.2f r(mean)
    quietly summarize full_pareto if treatment==`t', meanonly
    local h: display %4.2f r(mean)
    file write `texs' "`lab`t'' & `a' & `b' & `c' & `d' & `e' & `f' & `g' & `h' \\" _n
}
file write `texs' "\bottomrule\end{tabular}}" _n
file write `texs' "\begin{flushleft}\footnotesize Notes. Reports and first-stage assignments are fixed. Full take-up means filing every appealable claim that is truly preferred to the first-stage assignment. Probabilistic outcomes are integrated exactly. Stability is averaged first within matching group and then across matching groups; the remaining columns use participant- or market-level means.\end{flushleft}\end{table}" _n
file close `texs'

display as result "Full-take-up analysis finished."
display as result "Figures: $FTFIG"
display as result "Tables:  $FTTAB"
