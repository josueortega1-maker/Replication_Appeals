/**********************************************************************
 02_main_results.do

 Reproduces the empirical tables and figures in the main paper.
 Treatment order is always: no appeals, strict, probabilistic.
 Figure files have no internal title.
**********************************************************************/

version 18

capture program drop texcell
program define texcell, rclass
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

/* Common colors, close to the paper */
local da_no   "173 196 221"
local da_str  "31 73 125"
local da_prob "74 131 176"
local ia_no   "210 190 150"
local ia_str  "110 30 30"
local ia_prob "210 130 40"

/* Static theoretical Table 1 */
tempname static1
file open `static1' using "$TAB/table1_uphold_rules.tex", write replace
file write `static1' "\begin{table}[htbp]" _n
file write `static1' "\centering" _n
file write `static1' "\caption{Uphold rules}" _n
file write `static1' "\label{tab:upholdrules_rep}" _n
file write `static1' "\begin{tabular}{p{3.5cm}p{10cm}}" _n
file write `static1' "\toprule" _n
file write `static1' "Rule & An appeal by student \(i\) to school \(s\) is upheld if \\" _n
file write `static1' "\midrule" _n
file write `static1' "Strict rule (\(r_1\)) & \((i,s)\) is a strict blocking pair in the first-stage assignment. \\" _n
file write `static1' "Probabilistic rule (\(r_3\)) & \((i,s)\) is a strict blocking pair, or otherwise with independent probability \(p\). \\" _n
file write `static1' "\bottomrule" _n
file write `static1' "\end{tabular}" _n
file write `static1' "\end{table}" _n
file close `static1'

/**********************************************************************
 Figure 1: full-ranking truth-telling
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile fig1data
tempname fig1post
postfile `fig1post' byte treatment double mean se lo hi using `fig1data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress truthful if treatment == `t', vce(cluster session)
    local m = _b[_cons]
    local s = _se[_cons]
    post `fig1post' (`t') (`m') (`s') (`m' - 1.96*`s') (`m' + 1.96*`s')
}
postclose `fig1post'
use `fig1data', clear

gen byte xpos = .
replace xpos = 1 if treatment == 3
replace xpos = 2 if treatment == 2
replace xpos = 3 if treatment == 1
replace xpos = 5 if treatment == 6
replace xpos = 6 if treatment == 5
replace xpos = 7 if treatment == 4

twoway ///
    (bar mean xpos if treatment==3, barwidth(.70) color("`da_no'")) ///
    (bar mean xpos if treatment==2, barwidth(.70) color("`da_str'")) ///
    (bar mean xpos if treatment==1, barwidth(.70) color("`da_prob'")) ///
    (bar mean xpos if treatment==6, barwidth(.70) color("`ia_no'")) ///
    (bar mean xpos if treatment==5, barwidth(.70) color("`ia_str'")) ///
    (bar mean xpos if treatment==4, barwidth(.70) color("`ia_prob'")) ///
    (rcap hi lo xpos, lcolor(black) lwidth(medthin)) ///
    (scatter hi xpos, msymbol(none) mlabel(mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(1 `" "DA" "No appeals" "' 2 `" "DA" "Strict" "' 3 `" "DA" "Probabilistic" "' ///
           5 `" "IA" "No appeals" "' 6 `" "IA" "Strict" "' 7 `" "IA" "Probabilistic" "', noticks labsize(small)) ///
    ylabel(0(.2)1, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 1.06)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Share truth-telling") ///
    legend(off) graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figure1_truth_telling.pdf", replace
graph export "$FIG/figure1_truth_telling.png", width(2400) replace

/**********************************************************************
 Table 2: impact of appeals on truth-telling
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile table2data
tempname t2post
postfile `t2post' byte row spec double estimate se pvalue long N using `table2data', replace

forvalues spec = 1/4 {
    if `spec' == 1 quietly logit truthful i.treatment, vce(cluster session)
    if `spec' == 2 quietly logit truthful i.treatment i.round, vce(cluster session)
    if `spec' == 3 quietly logit truthful i.treatment i.round i.id_in_group, vce(cluster session)
    if `spec' == 4 quietly logit truthful i.treatment i.round i.id_in_group age female risk_aversion, vce(cluster session)
    local NN = e(N)
    quietly margins treatment, post

    quietly lincom 5.treatment - 6.treatment
    post `t2post' (1) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment - 6.treatment
    post `t2post' (2) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment - 3.treatment
    post `t2post' (3) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment - 3.treatment
    post `t2post' (4) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose `t2post'
use `table2data', clear
save "$DER/table2_truth_telling_estimates.dta", replace
export delimited using "$DER/table2_truth_telling_estimates.csv", replace

local rowlabel1 "IA strict"
local rowlabel2 "IA probabilistic"
local rowlabel3 "DA strict"
local rowlabel4 "DA probabilistic"

tempname tex2
file open `tex2' using "$TAB/table2_truth_telling.tex", write replace
file write `tex2' "\begin{table}[htbp]" _n
file write `tex2' "\centering" _n
file write `tex2' "\caption{Impact of appeals on truth-telling}" _n
file write `tex2' "\label{tab:truth_appeals_rep}" _n
file write `tex2' "\begin{threeparttable}" _n
file write `tex2' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcccc @{}}" _n
file write `tex2' "\toprule" _n
file write `tex2' "& \multicolumn{4}{c}{Specifications} \\" _n
file write `tex2' "& (1) & (2) & (3) & (4) \\" _n
file write `tex2' "\midrule" _n
file write `tex2' "\multicolumn{5}{l}{\textbf{Panel A. IA treatments}} \\" _n

forvalues r = 1/4 {
    if `r' == 3 file write `tex2' "\addlinespace" _n "\multicolumn{5}{l}{\textbf{Panel B. DA treatments}} \\" _n
    local line ""
    local seline ""
    forvalues s = 1/4 {
        quietly summarize estimate if row==`r' & spec==`s', meanonly
        local bb = r(mean)
        quietly summarize se if row==`r' & spec==`s', meanonly
        local ss = r(mean)
        quietly summarize pvalue if row==`r' & spec==`s', meanonly
        local pp = r(mean)
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `tex2' "`rowlabel`r''`line' \\" _n
    file write `tex2' "`seline' \\" _n
}

file write `tex2' "\addlinespace" _n
file write `tex2' "Round effects & No & Yes & Yes & Yes \\" _n
file write `tex2' "Participant-type effects & No & No & Yes & Yes \\" _n
file write `tex2' "Demographics + risk att. & No & No & No & Yes \\" _n
file write `tex2' "\midrule" _n
file write `tex2' "Observations & 10{,}195 & 10{,}195 & 10{,}195 & 10{,}185 \\" _n
file write `tex2' "Matching groups & 59 & 59 & 59 & 59 \\" _n
file write `tex2' "\bottomrule" _n
file write `tex2' "\end{tabular*}" _n
file write `tex2' "\begin{tablenotes}[flushleft]" _n
file write `tex2' "\footnotesize" _n
file write `tex2' "\item Notes. \(^{***}p<0.01\), \(^{**}p<0.05\), \(^{*}p<0.10\). Entries are average marginal effects from logit regressions. Standard errors are clustered at the matching-group level. Truth-telling equals one when the participant submits the complete induced preference ranking. The baseline in each panel is the corresponding mechanism without appeals." _n
file write `tex2' "\end{tablenotes}" _n
file write `tex2' "\end{threeparttable}" _n
file write `tex2' "\end{table}" _n
file close `tex2'

/**********************************************************************
 Figure 2: appeal take-up and success
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile fig2data
tempname fig2post
postfile `fig2post' byte treatment double take_mean take_se take_lo take_hi succ_mean succ_se succ_lo succ_hi using `fig2data', replace
foreach t in 2 1 5 4 {
    quietly regress appealed_any if treatment==`t' & offered_appeal==1, vce(cluster session)
    local mt = _b[_cons]
    local st = _se[_cons]
    quietly regress any_success if treatment==`t' & appealed_any==1, vce(cluster session)
    local ms = _b[_cons]
    local ss = _se[_cons]
    post `fig2post' (`t') (`mt') (`st') (`mt'-1.96*`st') (`mt'+1.96*`st') (`ms') (`ss') (`ms'-1.96*`ss') (`ms'+1.96*`ss')
}
postclose `fig2post'
use `fig2data', clear

gen byte xpos = .
replace xpos = 1 if treatment == 2
replace xpos = 2 if treatment == 1
replace xpos = 4 if treatment == 5
replace xpos = 5 if treatment == 4
gen double x_take = xpos - .18
gen double x_succ = xpos + .18

twoway ///
    (bar take_mean x_take if treatment==2, barwidth(.34) color("`da_str'")) ///
    (bar succ_mean x_succ if treatment==2, barwidth(.34) color("173 196 221")) ///
    (bar take_mean x_take if treatment==1, barwidth(.34) color("`da_prob'")) ///
    (bar succ_mean x_succ if treatment==1, barwidth(.34) color("190 210 230")) ///
    (bar take_mean x_take if treatment==5, barwidth(.34) color("`ia_str'")) ///
    (bar succ_mean x_succ if treatment==5, barwidth(.34) color("195 135 135")) ///
    (bar take_mean x_take if treatment==4, barwidth(.34) color("`ia_prob'")) ///
    (bar succ_mean x_succ if treatment==4, barwidth(.34) color("235 190 145")) ///
    (rcap take_hi take_lo x_take, lcolor(black) lwidth(medthin)) ///
    (rcap succ_hi succ_lo x_succ, lcolor(black) lwidth(medthin)) ///
    (scatter take_hi x_take, msymbol(none) mlabel(take_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2) mlabcolor(black)) ///
    (scatter succ_hi x_succ, msymbol(none) mlabel(succ_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(3, lcolor(gs12) lwidth(thin)) ///
    xlabel(1 `" "DA" "Strict" "' 2 `" "DA" "Probabilistic" "' 4 `" "IA" "Strict" "' 5 `" "IA" "Probabilistic" "', noticks labsize(small)) ///
    ylabel(0(.2)1, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 1.06)) xscale(range(.5 5.5)) ///
    xtitle("") ytitle("Share") ///
    legend(order(1 "Take-up" 2 "Success") cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figure2_appeal_takeup_success.pdf", replace
graph export "$FIG/figure2_appeal_takeup_success.png", width(2400) replace

/**********************************************************************
 Table 3: determinants of appeal use
**********************************************************************/
tempfile table3data
tempname t3post
postfile `t3post' byte row col double estimate se pvalue long N double r2 using `table3data', replace

use "$DER/appeal_rounds.dta", clear
quietly regress appealed_any ib2.treatment ib1.first_stage_rank any_strict n_opportunities i.round, vce(cluster session)
local NN = e(N)
local RR = e(r2)
foreach z in "1 1.treatment" "2 5.treatment" "3 4.treatment" "4 2.first_stage_rank" "5 3.first_stage_rank" "6 4.first_stage_rank" "7 any_strict" "8 n_opportunities" {
    tokenize `z'
    quietly lincom `2'
    post `t3post' (`1') (1) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
}

use "$DER/appeal_opportunities.dta", clear
quietly regress appeal_taken ib2.treatment ib1.first_stage_rank strict_claim ib1.target_rank i.round, vce(cluster session)
local NN = e(N)
local RR = e(r2)
foreach z in "1 1.treatment" "2 5.treatment" "3 4.treatment" "4 2.first_stage_rank" "5 3.first_stage_rank" "6 4.first_stage_rank" "7 strict_claim" {
    tokenize `z'
    quietly lincom `2'
    post `t3post' (`1') (2) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
}
quietly lincom 2.target_rank
post `t3post' (9) (2) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')
quietly lincom 3.target_rank
post `t3post' (10) (2) (r(estimate)) (r(se)) (r(p)) (`NN') (`RR')

postclose `t3post'
use `table3data', clear
save "$DER/table3_appeal_use_estimates.dta", replace
export delimited using "$DER/table3_appeal_use_estimates.csv", replace

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
file open `tex3' using "$TAB/table3_appeal_use.tex", write replace
file write `tex3' "\begin{table}[htbp]" _n
file write `tex3' "\centering" _n
file write `tex3' "\caption{Determinants of appeal use}" _n
file write `tex3' "\label{tab:appeal_use_rep}" _n
file write `tex3' "\begin{threeparttable}" _n
file write `tex3' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcc @{}}" _n
file write `tex3' "\toprule" _n
file write `tex3' "& Any appeal & Appeal opportunity taken \\" _n
file write `tex3' "\midrule" _n

forvalues r = 1/10 {
    local c1 "\(\cdot\)"
    local s1 ""
    local c2 "\(\cdot\)"
    local s2 ""
    quietly count if row==`r' & col==1
    if r(N)>0 {
        quietly summarize estimate if row==`r' & col==1, meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & col==1, meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & col==1, meanonly
        local pp=r(mean)
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local c1 "`r(coef)'"
        local s1 "`r(se)'"
    }
    quietly count if row==`r' & col==2
    if r(N)>0 {
        quietly summarize estimate if row==`r' & col==2, meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & col==2, meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & col==2, meanonly
        local pp=r(mean)
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local c2 "`r(coef)'"
        local s2 "`r(se)'"
    }
    if inlist(`r',4,7,8,9) file write `tex3' "\addlinespace" _n
    file write `tex3' "`rowlabel`r'' & `c1' & `c2' \\" _n
    file write `tex3' "& `s1' & `s2' \\" _n
}

file write `tex3' "\midrule" _n
file write `tex3' "Round fixed effects & Yes & Yes \\" _n
file write `tex3' "Observations & 2{,}912 & 5{,}725 \\" _n
file write `tex3' "Matching groups & 41 & 41 \\" _n
file write `tex3' "\(R^2\) & 0.16 & 0.03 \\" _n
file write `tex3' "\bottomrule" _n
file write `tex3' "\end{tabular*}" _n
file write `tex3' "\begin{tablenotes}[flushleft]" _n
file write `tex3' "\footnotesize" _n
file write `tex3' "\item Notes. \(^{***}p<0.01\), \(^{**}p<0.05\), \(^{*}p<0.10\). Entries are coefficients from linear probability models. Standard errors are clustered at the matching-group level. DA with strict appeals is the omitted treatment. Column \((1)\) contains one record for each participant-period with at least one appeal opportunity. Column \((2)\) contains one record for each school-specific appeal opportunity." _n
file write `tex3' "\end{tablenotes}" _n
file write `tex3' "\end{threeparttable}" _n
file write `tex3' "\end{table}" _n
file close `tex3'

/**********************************************************************
 Figure 3: average assigned rank, induced preferences
**********************************************************************/
use "$DER/analysis_sample.dta", clear

/* Assigned rank is evaluated against induced true preferences. */
assert assigned_rank == assigned_rank_check

tempfile fig3data
tempname fig3post
postfile `fig3post' byte treatment double rank_mean rank_se rank_lo rank_hi using `fig3data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress assigned_rank_check if treatment==`t', vce(cluster session)
    local mr=_b[_cons]
    local sr=_se[_cons]
    post `fig3post' (`t') (`mr') (`sr') (`mr'-1.96*`sr') (`mr'+1.96*`sr')
}
postclose `fig3post'
use `fig3data', clear

gen byte xpos=.
replace xpos=1 if treatment==3
replace xpos=2 if treatment==2
replace xpos=3 if treatment==1
replace xpos=5 if treatment==6
replace xpos=6 if treatment==5
replace xpos=7 if treatment==4

local xlabel6 1 `" "DA" "No appeals" "' 2 `" "DA" "Strict" "' 3 `" "DA" "Probabilistic" "' 5 `" "IA" "No appeals" "' 6 `" "IA" "Strict" "' 7 `" "IA" "Probabilistic" "'

twoway ///
    (bar rank_mean xpos if treatment==3, barwidth(.70) color("`da_no'")) ///
    (bar rank_mean xpos if treatment==2, barwidth(.70) color("`da_str'")) ///
    (bar rank_mean xpos if treatment==1, barwidth(.70) color("`da_prob'")) ///
    (bar rank_mean xpos if treatment==6, barwidth(.70) color("`ia_no'")) ///
    (bar rank_mean xpos if treatment==5, barwidth(.70) color("`ia_str'")) ///
    (bar rank_mean xpos if treatment==4, barwidth(.70) color("`ia_prob'")) ///
    (rcap rank_hi rank_lo xpos, lcolor(black) lwidth(medthin)) ///
    (scatter rank_hi xpos, msymbol(none) mlabel(rank_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(1(.5)4, angle(horizontal) glcolor(gs14)) ///
    yscale(range(1 4.10)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Average Rank") ///
    legend(off) graphregion(color(white)) plotregion(margin(zero)) bgcolor(white) ///
    xsize(8) ysize(4.8)

graph export "$FIG/figure3_rank_welfare.pdf", replace
graph export "$FIG/figure3_rank_welfare.png", width(2400) replace


/**********************************************************************
 Table 4: impact of appeals on assigned rank
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile table4data
tempname t4post
postfile `t4post' byte row spec double estimate se pvalue long N using `table4data', replace

forvalues spec = 1/4 {
    if `spec' == 1 quietly ologit assigned_rank i.treatment, vce(cluster session)
    if `spec' == 2 quietly ologit assigned_rank i.treatment i.round, vce(cluster session)
    if `spec' == 3 quietly ologit assigned_rank i.treatment i.round i.id_in_group, vce(cluster session)
    if `spec' == 4 quietly ologit assigned_rank i.treatment i.round i.id_in_group age female risk_aversion, vce(cluster session)
    local NN=e(N)
    quietly margins treatment, expression(predict(outcome(1))*1 + predict(outcome(2))*2 + predict(outcome(3))*3 + predict(outcome(4))*4) post

    quietly lincom 5.treatment - 6.treatment
    post `t4post' (1) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment - 6.treatment
    post `t4post' (2) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment - 3.treatment
    post `t4post' (3) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment - 3.treatment
    post `t4post' (4) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom (2.treatment - 5.treatment) - (3.treatment - 6.treatment)
    post `t4post' (5) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom (1.treatment - 4.treatment) - (3.treatment - 6.treatment)
    post `t4post' (6) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose `t4post'
use `table4data', clear
save "$DER/table4_rank_estimates.dta", replace
export delimited using "$DER/table4_rank_estimates.csv", replace

local rowlabel1 "IA strict"
local rowlabel2 "IA probabilistic"
local rowlabel3 "DA strict"
local rowlabel4 "DA probabilistic"
local rowlabel5 "Strict appeals"
local rowlabel6 "Probabilistic appeals"

tempname tex4
file open `tex4' using "$TAB/table4_assigned_rank.tex", write replace
file write `tex4' "\begin{table}[htbp]" _n
file write `tex4' "\centering" _n
file write `tex4' "\caption{Impact of appeals on assigned rank}" _n
file write `tex4' "\label{tab:rank_appeals_rep}" _n
file write `tex4' "\begin{threeparttable}" _n
file write `tex4' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcccc @{}}" _n
file write `tex4' "\toprule" _n
file write `tex4' "& \multicolumn{4}{c}{Specifications} \\" _n
file write `tex4' "& (1) & (2) & (3) & (4) \\" _n
file write `tex4' "\midrule" _n
file write `tex4' "\multicolumn{5}{l}{\textbf{Panel A. IA treatments}} \\" _n

forvalues r=1/6 {
    if `r'==3 file write `tex4' "\addlinespace" _n "\multicolumn{5}{l}{\textbf{Panel B. DA treatments}} \\" _n
    if `r'==5 file write `tex4' "\addlinespace" _n "\multicolumn{5}{l}{\textbf{Panel C. Increase in the DA--IA rank gap relative to no appeals}} \\" _n
    local line ""
    local seline ""
    forvalues s=1/4 {
        quietly summarize estimate if row==`r' & spec==`s', meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & spec==`s', meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & spec==`s', meanonly
        local pp=r(mean)
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `tex4' "`rowlabel`r''`line' \\" _n
    file write `tex4' "`seline' \\" _n
}

file write `tex4' "\addlinespace" _n
file write `tex4' "Round effects & No & Yes & Yes & Yes \\" _n
file write `tex4' "Participant-type effects & No & No & Yes & Yes \\" _n
file write `tex4' "Demographics + risk att. & No & No & No & Yes \\" _n
file write `tex4' "\midrule" _n
file write `tex4' "Observations & 10{,}195 & 10{,}195 & 10{,}195 & 10{,}185 \\" _n
file write `tex4' "Matching groups & 59 & 59 & 59 & 59 \\" _n
file write `tex4' "\bottomrule" _n
file write `tex4' "\end{tabular*}" _n
file write `tex4' "\begin{tablenotes}[flushleft]" _n
file write `tex4' "\footnotesize" _n
file write `tex4' "\item Notes. \(^{***}p<0.01\), \(^{**}p<0.05\), \(^{*}p<0.10\). Entries are adjusted differences in expected assigned rank from ordered logit models. Lower values indicate better assignments. The baselines in Panels A and B are the corresponding mechanisms without appeals. Positive values in Panel C indicate that appeals widen IA's rank advantage." _n
file write `tex4' "\end{tablenotes}" _n
file write `tex4' "\end{threeparttable}" _n
file write `tex4' "\end{table}" _n
file close `tex4'

/**********************************************************************
 Table 5: welfare decomposition
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile table5data
tempname t5post
postfile `t5post' byte treatment double total total_se total_p reporting reporting_se reporting_p direct direct_se direct_p using `table5data', replace

foreach pair in "2 3" "1 3" "5 6" "4 6" {
    tokenize `pair'
    local t=`1'
    local b=`2'

    quietly regress welfare_points i.treatment if inlist(treatment,`t',`b'), vce(cluster session)
    quietly margins treatment, post
    quietly lincom `t'.treatment - `b'.treatment
    local total=r(estimate)
    local total_se=r(se)
    local total_p=r(p)

    use "$DER/analysis_sample.dta", clear
    quietly regress first_stage_points i.treatment if inlist(treatment,`t',`b'), vce(cluster session)
    quietly margins treatment, post
    quietly lincom `t'.treatment - `b'.treatment
    local reporting=r(estimate)
    local reporting_se=r(se)
    local reporting_p=r(p)

    use "$DER/analysis_sample.dta", clear
    quietly regress direct_appeal_gain if treatment==`t', vce(cluster session)
    local direct=_b[_cons]
    local direct_se=_se[_cons]
    local direct_p=.
    if `direct_se'>0 local direct_p=2*ttail(e(df_r),abs(`direct'/`direct_se'))

    post `t5post' (`t') (`total') (`total_se') (`total_p') (`reporting') (`reporting_se') (`reporting_p') (`direct') (`direct_se') (`direct_p')
}
postclose `t5post'
use `table5data', clear
save "$DER/table5_welfare_decomposition.dta", replace
export delimited using "$DER/table5_welfare_decomposition.csv", replace

local rowlabel2 "DA, strict appeals"
local rowlabel1 "DA, probabilistic appeals"
local rowlabel5 "IA, strict appeals"
local rowlabel4 "IA, probabilistic appeals"

tempname tex5
file open `tex5' using "$TAB/table5_welfare_decomposition.tex", write replace
file write `tex5' "\begin{table}[htbp]" _n
file write `tex5' "\centering" _n
file write `tex5' "\caption{Decomposition of welfare changes relative to no appeals}" _n
file write `tex5' "\label{tab:welfare_decomposition_rep}" _n
file write `tex5' "\begin{threeparttable}" _n
file write `tex5' "\begin{tabular}{lccc}" _n
file write `tex5' "\toprule" _n
file write `tex5' "Treatment & Total effect & Reporting channel & Direct appeal channel \\" _n
file write `tex5' "\midrule" _n
foreach t in 2 1 5 4 {
    quietly summarize total if treatment==`t', meanonly
    local b1=r(mean)
    quietly summarize total_se if treatment==`t', meanonly
    local s1=r(mean)
    quietly summarize total_p if treatment==`t', meanonly
    local p1=r(mean)
    quietly texcell, b(`b1') se(`s1') p(`p1') digits(2)
    local c1="`r(coef)'"
    local e1="`r(se)'"

    quietly summarize reporting if treatment==`t', meanonly
    local b2=r(mean)
    quietly summarize reporting_se if treatment==`t', meanonly
    local s2=r(mean)
    quietly summarize reporting_p if treatment==`t', meanonly
    local p2=r(mean)
    quietly texcell, b(`b2') se(`s2') p(`p2') digits(2)
    local c2="`r(coef)'"
    local e2="`r(se)'"

    quietly summarize direct if treatment==`t', meanonly
    local b3=r(mean)
    quietly summarize direct_se if treatment==`t', meanonly
    local s3=r(mean)
    quietly summarize direct_p if treatment==`t', meanonly
    local p3=r(mean)
    quietly texcell, b(`b3') se(`s3') p(`p3') digits(2)
    local c3="`r(coef)'"
    local e3="`r(se)'"

    if `t'==5 file write `tex5' "\addlinespace" _n
    file write `tex5' "`rowlabel`t'' & `c1' & `c2' & `c3' \\" _n
    file write `tex5' "& `e1' & `e2' & `e3' \\" _n
}
file write `tex5' "\bottomrule" _n
file write `tex5' "\end{tabular}" _n
file write `tex5' "\begin{tablenotes}[flushleft]" _n
file write `tex5' "\footnotesize" _n
file write `tex5' "\item Notes. Outcomes are experimental points. The total effect compares final welfare in an appeal treatment with final welfare under the same first-stage mechanism without appeals. The reporting channel makes the corresponding comparison before appeals are resolved. The direct channel is the within-treatment difference between final and first-stage welfare. Standard errors are clustered at the matching-group level." _n
file write `tex5' "\end{tablenotes}" _n
file write `tex5' "\end{threeparttable}" _n
file write `tex5' "\end{table}" _n
file close `tex5'

/**********************************************************************
 Pareto dominance statistics used in the main text
**********************************************************************/
use "$DER/market_rounds.dta", clear

tempfile paretodata
tempname paretopost
postfile `paretopost' byte treatment long markets weak_n strict_n double weak_share strict_share using `paretodata', replace
foreach t in 3 2 1 6 5 4 {
    quietly count if treatment==`t'
    local n=r(N)
    quietly count if treatment==`t' & weak_pareto_da==1
    local nw=r(N)
    quietly count if treatment==`t' & strict_pareto_da==1
    local ns=r(N)
    post `paretopost' (`t') (`n') (`nw') (`ns') (`nw'/`n') (`ns'/`n')
}
postclose `paretopost'
use `paretodata', clear
save "$DER/pareto_dominance_summary.dta", replace
export delimited using "$DER/pareto_dominance_summary.csv", replace

use "$DER/market_rounds.dta", clear
quietly regress weak_pareto_da i.treatment if inlist(treatment,5,6), vce(cluster session)
quietly lincom 5.treatment - 6.treatment
local weakdiff=r(estimate)
local weakse=r(se)
local weakp=r(p)
quietly regress strict_pareto_da i.treatment if inlist(treatment,5,6), vce(cluster session)
quietly lincom 5.treatment - 6.treatment
local strictdiff=r(estimate)
local strictse=r(se)
local strictp=r(p)

tempname texp
file open `texp' using "$TAB/table_pareto_dominance.tex", write replace
file write `texp' "\begin{table}[htbp]" _n
file write `texp' "\centering" _n
file write `texp' "\caption{Realized assignments relative to truthful DA}" _n
file write `texp' "\label{tab:pareto_rep}" _n
file write `texp' "\begin{tabular}{lccc}" _n
file write `texp' "\toprule" _n
file write `texp' "Treatment & Markets & Weak dominance & Strict dominance \\" _n
file write `texp' "\midrule" _n
use `paretodata', clear
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
    local nwstr : display %9.0f `nw'
    local swstr : display %5.2f `sw'
    local nsstr : display %9.0f `ns'
    local ssstr : display %5.2f `ss'
    file write `texp' "`lab`t'' & `nstr' & `nwstr' (`swstr'\%) & `nsstr' (`ssstr'\%) \\" _n
}
file write `texp' "\bottomrule" _n
file write `texp' "\end{tabular}" _n
local weakdiffstr : display %5.2f 100*`weakdiff'
local weaksestr : display %5.2f 100*`weakse'
local strictdiffstr : display %5.2f 100*`strictdiff'
local strictsestr : display %5.2f 100*`strictse'
file write `texp' "\begin{flushleft}\footnotesize Notes. Dominance is evaluated against the truthful DA assignment using induced preferences. The strict-appeal treatment raises weak dominance under IA by `weakdiffstr' percentage points, with clustered standard error `weaksestr'. It raises strict dominance by `strictdiffstr' percentage points, with clustered standard error `strictsestr'.\end{flushleft}" _n
file write `texp' "\end{table}" _n
file close `texp'

/**********************************************************************
 Figure 4: stability under submitted and induced preferences
**********************************************************************/
use "$DER/market_rounds.dta", clear
/* The published descriptive bars weight each independent session equally. */
collapse (mean) stable_sub stable_true, by(treatment session)

tempfile fig4data
tempname fig4post
postfile `fig4post' byte treatment double sub_mean sub_se sub_lo sub_hi true_mean true_se true_lo true_hi using `fig4data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress stable_sub if treatment==`t'
    local m1=_b[_cons]
    local s1=_se[_cons]
    quietly regress stable_true if treatment==`t'
    local m2=_b[_cons]
    local s2=_se[_cons]
    post `fig4post' (`t') (`m1') (`s1') (`m1'-1.96*`s1') (`m1'+1.96*`s1') (`m2') (`s2') (`m2'-1.96*`s2') (`m2'+1.96*`s2')
}
postclose `fig4post'
use `fig4data', clear

gen byte xpos=.
replace xpos=1 if treatment==3
replace xpos=2 if treatment==2
replace xpos=3 if treatment==1
replace xpos=5 if treatment==6
replace xpos=6 if treatment==5
replace xpos=7 if treatment==4
gen double x_sub=xpos-.18
gen double x_true=xpos+.18

twoway ///
    (bar sub_mean x_sub, barwidth(.34) color("31 119 180")) ///
    (bar true_mean x_true, barwidth(.34) color("255 127 14")) ///
    (rcap sub_hi sub_lo x_sub, lcolor(black) lwidth(medthin)) ///
    (rcap true_hi true_lo x_true, lcolor(black) lwidth(medthin)) ///
    (scatter sub_hi x_sub, msymbol(none) mlabel(sub_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2) mlabcolor(black)) ///
    (scatter true_hi x_true, msymbol(none) mlabel(true_mean) mlabformat(%4.2f) mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(0(.2)1, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 1.08)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Share of stable market-rounds") ///
    legend(order(1 "Submitted preferences" 2 "Induced preferences") cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figure4_stability.pdf", replace
graph export "$FIG/figure4_stability.png", width(2400) replace

/**********************************************************************
 Table 6: impact of appeals on stability
**********************************************************************/
use "$DER/market_rounds.dta", clear

tempfile table6data
tempname t6post
postfile `t6post' byte row col double estimate se pvalue long N using `table6data', replace

local outcome1 "strict_bp_sub"
local outcome2 "waste_sub"
local outcome3 "stable_sub"
forvalues c=1/3 {
    quietly regress `outcome`c'' ib3.treatment i.round, vce(cluster session)
    local NN=e(N)
    quietly lincom 5.treatment - 6.treatment
    post `t6post' (1) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment - 6.treatment
    post `t6post' (2) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment
    post `t6post' (3) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment
    post `t6post' (4) (`c') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose `t6post'
use `table6data', clear
save "$DER/table6_stability_estimates.dta", replace
export delimited using "$DER/table6_stability_estimates.csv", replace

local rowlabel1 "IA strict"
local rowlabel2 "IA probabilistic"
local rowlabel3 "DA strict"
local rowlabel4 "DA probabilistic"

tempname tex6
file open `tex6' using "$TAB/table6_stability.tex", write replace
file write `tex6' "\begin{table}[htbp]" _n
file write `tex6' "\centering" _n
file write `tex6' "\caption{Impact of appeals on stability}" _n
file write `tex6' "\label{tab:stability_effects_rep}" _n
file write `tex6' "\begin{threeparttable}" _n
file write `tex6' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lccc @{}}" _n
file write `tex6' "\toprule" _n
file write `tex6' "& Strict blocking pairs & Wasted-seat claims & Stable market-round \\" _n
file write `tex6' "& (1) & (2) & (3) \\" _n
file write `tex6' "\midrule" _n
file write `tex6' "\multicolumn{4}{l}{\textbf{Panel A. IA treatments}} \\" _n
forvalues r=1/4 {
    if `r'==3 file write `tex6' "\addlinespace" _n "\multicolumn{4}{l}{\textbf{Panel B. DA treatments}} \\" _n
    local line ""
    local seline ""
    forvalues c=1/3 {
        quietly summarize estimate if row==`r' & col==`c', meanonly
        local bb=r(mean)
        quietly summarize se if row==`r' & col==`c', meanonly
        local ss=r(mean)
        quietly summarize pvalue if row==`r' & col==`c', meanonly
        local pp=r(mean)
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `tex6' "`rowlabel`r''`line' \\" _n
    file write `tex6' "`seline' \\" _n
}
file write `tex6' "\addlinespace" _n
file write `tex6' "Round effects & Yes & Yes & Yes \\" _n
file write `tex6' "\midrule" _n
file write `tex6' "Observations & 1{,}435 & 1{,}435 & 1{,}435 \\" _n
file write `tex6' "Matching groups & 59 & 59 & 59 \\" _n
file write `tex6' "\bottomrule" _n
file write `tex6' "\end{tabular*}" _n
file write `tex6' "\begin{tablenotes}[flushleft]" _n
file write `tex6' "\footnotesize" _n
file write `tex6' "\item Notes. \(^{***}p<0.01\), \(^{**}p<0.05\), \(^{*}p<0.10\). Entries are coefficients from linear regressions with round effects. Standard errors are clustered at the matching-group level. Outcomes use submitted preferences. Equal-priority tie-break claims are excluded from strict blocking pairs. A market-round is stable when it contains neither a strict blocking pair nor a wasted-seat claim." _n
file write `tex6' "\end{tablenotes}" _n
file write `tex6' "\end{threeparttable}" _n
file write `tex6' "\end{table}" _n
file close `tex6'

/**********************************************************************
 Figure 5: normalized comparison of rank-efficiency, truth-telling,
 and procedural stability
**********************************************************************/
use "$DER/analysis_sample.dta", clear
collapse (mean) truth=truthful rank=assigned_rank, by(treatment)
gen double rank_eff = 4 - rank
tempfile participant_metrics
save `participant_metrics'

use "$DER/market_rounds.dta", clear
/* Match the published radar by first averaging stability within session. */
collapse (mean) stable_sub, by(treatment session)
collapse (mean) procedural_stability=stable_sub, by(treatment)
merge 1:1 treatment using `participant_metrics', nogen

quietly summarize truth, meanonly
replace truth = truth / r(max)
quietly summarize rank_eff, meanonly
replace rank_eff = rank_eff / r(max)
quietly summarize procedural_stability, meanonly
replace procedural_stability = procedural_stability / r(max)

expand 4
bysort treatment: gen byte vertex=_n
gen double metric=.
replace metric=truth if inlist(vertex,1,4)
replace metric=rank_eff if vertex==2
replace metric=procedural_stability if vertex==3

gen double angle=.
replace angle=_pi/2 if inlist(vertex,1,4)
replace angle=-_pi/6 if vertex==2
replace angle=7*_pi/6 if vertex==3

gen double x=metric*cos(angle)
gen double y=metric*sin(angle)
gen byte grid=.
gen int plotid=10+treatment

tempfile radar_series
save `radar_series'

clear
set obs 16
gen byte grid=ceil(_n/4)
bysort grid: gen byte vertex=_n
gen double metric=.25*grid
gen double angle=.
replace angle=_pi/2 if inlist(vertex,1,4)
replace angle=-_pi/6 if vertex==2
replace angle=7*_pi/6 if vertex==3
gen double x=metric*cos(angle)
gen double y=metric*sin(angle)
gen byte treatment=.
gen int plotid=grid
append using `radar_series'
sort plotid vertex

twoway ///
    (line y x if grid==1, lcolor(gs14) lwidth(vthin)) ///
    (line y x if grid==2, lcolor(gs14) lwidth(vthin)) ///
    (line y x if grid==3, lcolor(gs14) lwidth(vthin)) ///
    (line y x if grid==4, lcolor(gs12) lwidth(thin)) ///
    (connected y x if treatment==3, lcolor("`da_no'") mcolor("`da_no'") msymbol(O) lwidth(medthick)) ///
    (connected y x if treatment==2, lcolor("`da_str'") mcolor("`da_str'") msymbol(O) lwidth(medthick)) ///
    (connected y x if treatment==1, lcolor("`da_prob'") mcolor("`da_prob'") msymbol(O) lwidth(medthick)) ///
    (connected y x if treatment==6, lcolor("`ia_no'") mcolor("`ia_no'") msymbol(O) lwidth(medthick)) ///
    (connected y x if treatment==5, lcolor("`ia_str'") mcolor("`ia_str'") msymbol(O) lwidth(medthick)) ///
    (connected y x if treatment==4, lcolor("`ia_prob'") mcolor("`ia_prob'") msymbol(O) lwidth(medthick)), ///
    text(1.12 0 "Truth-telling", size(small)) ///
    text(-.64 1.02 "Rank-efficiency", size(small)) ///
    text(-.64 -1.02 "Procedural stability", size(small)) ///
    xscale(range(-1.20 1.20) off) yscale(range(-1.05 1.22) off) ///
    xlabel(, nogrid) ylabel(, nogrid) aspect(1) ///
    legend(order(5 "DA, no appeals" 6 "DA, strict" 7 "DA, probabilistic" 8 "IA, no appeals" 9 "IA, strict" 10 "IA, probabilistic") cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(small)) bgcolor(white)

graph export "$FIG/figure5_normalized_comparison.pdf", replace
graph export "$FIG/figure5_normalized_comparison.png", width(2400) replace

clear
