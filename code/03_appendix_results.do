/**********************************************************************
 03_appendix_results.do

 Additional laboratory results, in the order used in the main text:
   D.1 Nonparametric tests on matching-group means
   D.2 First-choice truth-telling
   D.3 Efficiency in experimental points
   D.4 Strict blocking pairs

 Treatment order is always: no appeals, strict, probabilistic.
 All participant-level analyses use the 10,195-observation paper sample.
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

/* Common colors, matching the main-text figures */
local da_no   "173 196 221"
local da_str  "31 73 125"
local da_prob "74 131 176"
local ia_no   "210 190 150"
local ia_str  "110 30 30"
local ia_prob "210 130 40"

local xlabel6 1 `" "DA" "No appeals" "' ///
              2 `" "DA" "Strict" "' ///
              3 `" "DA" "Probabilistic" "' ///
              5 `" "IA" "No appeals" "' ///
              6 `" "IA" "Strict" "' ///
              7 `" "IA" "Probabilistic" "'

/**********************************************************************
 Sample checks
**********************************************************************/
use "$DER/analysis_sample.dta", clear
assert _N == 10195
quietly count if !missing(age, female, risk_aversion)
assert r(N) == 10185
egen byte appendix_session_tag = tag(session)
quietly count if appendix_session_tag == 1
assert r(N) == 59
drop appendix_session_tag


/**********************************************************************
 D.1 Nonparametric tests on matching-group means

 The reported p-values use the two-sided Mann--Whitney normal
 approximation with the standard continuity correction and tie-adjusted
 variance. This reproduces the values in the paper. They are not labelled
 "exact" because session means contain ties.

 Participant-level outcomes are first averaged within session.
 Market-level outcomes are first averaged over complete market-rounds
 within session. Each session therefore contributes exactly one
 independent observation to each comparison.
**********************************************************************/

/* Mann--Whitney p-value + Hodges--Lehmann location shift */
capture program drop d1_mw_hl
program define d1_mw_hl, rclass
    syntax varname(numeric), T1(integer) T0(integer)

    tempfile d1_arm1
    local n1 = .
    local n0 = .
    local hl = .
    local p = .
    local z = .
    local degenerate = 0

    /* Hodges--Lehmann shift: median of all x_i - y_j differences */
    preserve
        keep if treatment == `t1'
        keep `varlist'
        drop if missing(`varlist')
        rename `varlist' d1_x
        gen byte d1_join = 1
        local n1 = _N
        save `d1_arm1', replace
    restore

    preserve
        keep if treatment == `t0'
        keep `varlist'
        drop if missing(`varlist')
        rename `varlist' d1_y
        gen byte d1_join = 1
        local n0 = _N
        joinby d1_join using `d1_arm1'
        gen double d1_diff = d1_x - d1_y
        quietly summarize d1_diff, detail
        local hl = r(p50)
    restore

    /* Mann--Whitney normal approximation with continuity correction.
       Average ranks and the variance are adjusted for ties. */
    preserve
        keep if inlist(treatment, `t1', `t0')
        keep treatment `varlist'
        drop if missing(`varlist')

        quietly summarize `varlist', meanonly
        if r(min) == r(max) {
            local degenerate = 1
        }
        else {
            gen byte d1_g = treatment == `t1'
            egen double d1_rank = rank(`varlist')

            quietly summarize d1_rank if d1_g == 1, meanonly
            local W = r(sum)

            local U  = `W' - `n1' * (`n1' + 1) / 2
            local mu = `n1' * `n0' / 2
            local N  = `n1' + `n0'

            bysort `varlist': gen long d1_tie_n = _N
            bysort `varlist': gen byte d1_tie_tag = (_n == 1)
            gen double d1_tie_term = ///
                (d1_tie_n^3 - d1_tie_n) * d1_tie_tag
            quietly summarize d1_tie_term, meanonly
            local tiesum = r(sum)

            local varU = `n1' * `n0' / 12 * ///
                ((`N' + 1) - `tiesum' / (`N' * (`N' - 1)))

            if `varU' <= 0 {
                local degenerate = 1
            }
            else {
                local d = `U' - `mu'
                local z = 0
                if `d' > 0 local z = (`d' - 0.5) / sqrt(`varU')
                if `d' < 0 local z = (`d' + 0.5) / sqrt(`varU')
                local p = 2 * normal(-abs(`z'))
            }
        }
    restore

    return scalar n1 = `n1'
    return scalar n0 = `n0'
    return scalar degenerate = `degenerate'
    if `degenerate' {
        return scalar estimate = .
        return scalar pvalue = .
        return scalar z = .
    }
    else {
        return scalar estimate = `hl'
        return scalar pvalue = `p'
        return scalar z = `z'
    }
end

/* Build one observation per independent matching group. */
use "$DER/analysis_sample.dta", clear
collapse (mean) truth=truthful rank=assigned_rank, by(treatment session)
tempfile d1_participant_means
save `d1_participant_means', replace

use "$DER/market_rounds.dta", clear
collapse (mean) stable=stable_sub bp=strict_bp_sub, by(treatment session)
merge 1:1 treatment session using `d1_participant_means', assert(3) nogen

assert _N == 59
quietly count if treatment == 1
assert r(N) == 11
quietly count if treatment == 2
assert r(N) == 9
quietly count if treatment == 3
assert r(N) == 9
quietly count if treatment == 4
assert r(N) == 12
quietly count if treatment == 5
assert r(N) == 9
quietly count if treatment == 6
assert r(N) == 9

save "$DER/tableD1_nonparametric_session_means.dta", replace
export delimited using "$DER/tableD1_nonparametric_session_means.csv", replace

/* Rows:
   1 DA strict - DA no appeals
   2 DA probabilistic - DA no appeals
   3 IA strict - IA no appeals
   4 IA probabilistic - IA no appeals
   5 IA - DA, no appeals
   6 IA - DA, strict appeals
   7 IA - DA, probabilistic appeals
*/
local t1list "2 1 5 4 6 5 4"
local t0list "3 3 6 6 3 2 1"
local outcome1 "truth"
local outcome2 "rank"
local outcome3 "stable"
local outcome4 "bp"

tempfile d1_results
tempname d1post
postfile `d1post' byte row col treatment_a treatment_b ///
    double estimate pvalue z long n1 n0 byte degenerate ///
    using `d1_results', replace

forvalues r = 1/7 {
    local t1 : word `r' of `t1list'
    local t0 : word `r' of `t0list'

    forvalues c = 1/4 {
        quietly d1_mw_hl `outcome`c'', t1(`t1') t0(`t0')
        post `d1post' (`r') (`c') (`t1') (`t0') ///
            (r(estimate)) (r(pvalue)) (r(z)) ///
            (r(n1)) (r(n0)) (r(degenerate))
    }
}
postclose `d1post'

use `d1_results', clear
sort row col
assert _N == 28
save "$DER/tableD1_nonparametric_estimates.dta", replace
export delimited using "$DER/tableD1_nonparametric_estimates.csv", replace

/* Generate the paper table. */
local rowlabel1 "DA strict \(-\) DA no appeals"
local rowlabel2 "DA probabilistic \(-\) DA no appeals"
local rowlabel3 "IA strict \(-\) IA no appeals"
local rowlabel4 "IA probabilistic \(-\) IA no appeals"
local rowlabel5 "No appeals"
local rowlabel6 "Strict appeals"
local rowlabel7 "Probabilistic appeals"

tempname texD0
file open `texD0' using "$TAB/tableD1_nonparametric.tex", write replace
file write `texD0' "\begin{table}[htbp]" _n
file write `texD0' "\centering" _n
file write `texD0' "\caption{Nonparametric tests on matching-group means.}" _n
file write `texD0' "\label{tab:nonparametric}" _n
file write `texD0' "\resizebox{\textwidth}{!}{\begin{threeparttable}" _n
file write `texD0' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcccc @{}}" _n
file write `texD0' "\toprule" _n
file write `texD0' "& Truth-telling & Mean assigned rank & Stable share & Blocking pairs \\" _n
file write `texD0' "& (full ranking) & (induced) & (submitted) & (submitted) \\" _n
file write `texD0' "& \((1)\) & \((2)\) & \((3)\) & \((4)\) \\" _n
file write `texD0' "\midrule" _n
file write `texD0' "\multicolumn{5}{l}{\textbf{Panel A. Appeal effects within mechanism}} \\" _n

forvalues r = 1/7 {
    if `r' == 5 {
        file write `texD0' "\addlinespace" _n
        file write `texD0' "\multicolumn{5}{l}{\textbf{Panel B. IA \(-\) DA at each appeal regime}} \\" _n
    }

    local coefline ""
    local pline ""

    forvalues c = 1/4 {
        quietly summarize degenerate if row == `r' & col == `c', meanonly
        local deg = r(mean)

        if `deg' == 1 {
            local coefline "`coefline' & ---"
            local pline "`pline' & "
        }
        else {
            quietly summarize estimate if row == `r' & col == `c', meanonly
            local bb = r(mean)
            quietly summarize pvalue if row == `r' & col == `c', meanonly
            local pp = r(mean)

            if abs(`bb') < .005 local bb = 0
            local btxt = strtrim(string(`bb', "%9.2f"))

            local stars ""
            if `pp' < 0.01 local stars "***"
            else if `pp' < 0.05 local stars "**"
            else if `pp' < 0.10 local stars "*"

            if "`stars'" == "" local bcell "\(`btxt'\)"
            else local bcell "\(`btxt'^{`stars'}\)"
            local coefline "`coefline' & `bcell'"

            if `pp' < .001 {
                local pcell "{\footnotesize \([<0.001]\)}"
            }
            else {
                local ptxt = strtrim(string(`pp', "%5.3f"))
                local pcell "{\footnotesize \([`ptxt']\)}"
            }
            local pline "`pline' & `pcell'"
        }
    }

    file write `texD0' "`rowlabel`r''`coefline' \\" _n
    file write `texD0' "`pline' \\" _n
}

file write `texD0' "\bottomrule" _n
file write `texD0' "\end{tabular*}" _n
file write `texD0' "\begin{tablenotes}" _n
file write `texD0' "\footnotesize" _n
file write `texD0' "\item \(^{***}\ p<0.01\); \(^{**}\ p<0.05\); \(^{*}\ p<0.10\). Entries are Hodges--Lehmann location shifts, that is, the median of all pairwise differences between matching-group means in the two arms; two-sided Mann--Whitney \(p\)-values are in brackets. Each observation is one matching group: participant-level outcomes are averaged over all participant-rounds in a session, and market-level outcomes over all complete market-rounds in a session. There are nine matching groups in each arm except DA probabilistic (eleven) and IA probabilistic (twelve), so every comparison rests on between \(18\) and \(23\) independent observations. Lower values are better in Columns~(2) and~(4). Cells marked --- have no variation in either arm: DA is stable with respect to submitted preferences by construction, so submitted stability equals one and the submitted blocking-pair count equals zero in every DA market-round without appeals and with strict appeals. \(p\)-values are unadjusted for multiple testing." _n
file write `texD0' "\end{tablenotes}" _n
file write `texD0' "\end{threeparttable}}" _n
file write `texD0' "\end{table}" _n
file close `texD0'


/**********************************************************************
 D.2 First-choice truth-telling by treatment
**********************************************************************/

tempfile figD1data
tempname figD1post
postfile `figD1post' byte treatment double mean se lo hi using `figD1data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress top_choice_truth if treatment == `t', vce(cluster session)
    local m = _b[_cons]
    local s = _se[_cons]
    post `figD1post' (`t') (`m') (`s') (`m' - 1.96*`s') (`m' + 1.96*`s')
}
postclose `figD1post'
use `figD1data', clear

save "$DER/figureD1_first_choice_truth.dta", replace
export delimited using "$DER/figureD1_first_choice_truth.csv", replace

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
    (scatter hi xpos, msymbol(none) mlabel(mean) mlabformat(%4.2f) ///
        mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(0(.2)1, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 1.06)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Share ranking true first choice first") ///
    legend(off) graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figureD1_first_choice_truth.pdf", replace
graph export "$FIG/figureD1_first_choice_truth.png", width(2400) replace

/**********************************************************************
 Table D.2: impact of appeals on first-choice truth-telling
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile tableD1data
tempname tableD1post
postfile `tableD1post' byte row spec double estimate se pvalue long N using `tableD1data', replace

forvalues spec = 1/4 {
    if `spec' == 1 quietly logit top_choice_truth i.treatment, vce(cluster session)
    if `spec' == 2 quietly logit top_choice_truth i.treatment i.round, vce(cluster session)
    if `spec' == 3 quietly logit top_choice_truth i.treatment i.round i.id_in_group, vce(cluster session)
    if `spec' == 4 quietly logit top_choice_truth i.treatment i.round i.id_in_group age female risk_aversion, vce(cluster session)
    local NN = e(N)
    if `spec' < 4 assert `NN' == 10195
    if `spec' == 4 assert `NN' == 10185

    quietly margins treatment, post

    quietly lincom 5.treatment - 6.treatment
    post `tableD1post' (1) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment - 6.treatment
    post `tableD1post' (2) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment - 3.treatment
    post `tableD1post' (3) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment - 3.treatment
    post `tableD1post' (4) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose `tableD1post'
use `tableD1data', clear
save "$DER/tableD1_first_choice_truth_estimates.dta", replace
export delimited using "$DER/tableD1_first_choice_truth_estimates.csv", replace

local rowlabel1 "IA strict"
local rowlabel2 "IA probabilistic"
local rowlabel3 "DA strict"
local rowlabel4 "DA probabilistic"

tempname texD1
file open `texD1' using "$TAB/tableD1_first_choice_truth.tex", write replace
file write `texD1' "\begin{table}[htbp]" _n
file write `texD1' "\centering" _n
file write `texD1' "\caption{Impact of appeals on first-choice truth-telling}" _n
file write `texD1' "\label{tab:first_choice_truth_appeals}" _n
file write `texD1' "\begin{threeparttable}" _n
file write `texD1' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcccc @{}}" _n
file write `texD1' "\toprule" _n
file write `texD1' "& \multicolumn{4}{c}{Specifications} \\" _n
file write `texD1' "& (1) & (2) & (3) & (4) \\" _n
file write `texD1' "\midrule" _n
file write `texD1' "\multicolumn{5}{l}{\textbf{Panel A. IA treatments}} \\" _n

forvalues r = 1/4 {
    if `r' == 3 file write `texD1' "\addlinespace" _n "\multicolumn{5}{l}{\textbf{Panel B. DA treatments}} \\" _n
    local line ""
    local seline ""
    forvalues s = 1/4 {
        quietly summarize estimate if row==`r' & spec==`s', meanonly
        local bb = r(mean)
        quietly summarize se if row==`r' & spec==`s', meanonly
        local ss = r(mean)
        quietly summarize pvalue if row==`r' & spec==`s', meanonly
        local pp = r(mean)
        if abs(`bb') < .005 local bb = 0
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `texD1' "`rowlabel`r''`line' \\" _n
    file write `texD1' "`seline' \\" _n
}

file write `texD1' "\addlinespace" _n
file write `texD1' "Round effects & No & Yes & Yes & Yes \\" _n
file write `texD1' "Participant-type effects & No & No & Yes & Yes \\" _n
file write `texD1' "Demographics + risk att. & No & No & No & Yes \\" _n
file write `texD1' "\midrule" _n
file write `texD1' "Observations & 10{,}195 & 10{,}195 & 10{,}195 & 10{,}185 \\" _n
file write `texD1' "Matching groups & 59 & 59 & 59 & 59 \\" _n
file write `texD1' "\bottomrule" _n
file write `texD1' "\end{tabular*}" _n
file write `texD1' "\begin{tablenotes}[flushleft]" _n
file write `texD1' "\footnotesize" _n
file write `texD1' "\item Notes. \(^{***}p<0.01\), \(^{**}p<0.05\), \(^{*}p<0.10\). Entries are average marginal effects from logit regressions. Standard errors are clustered at the matching-group level. First-choice truth-telling equals one when the participant ranks her induced first-choice school first. The baseline in each panel is the corresponding mechanism without appeals." _n
file write `texD1' "\end{tablenotes}" _n
file write `texD1' "\end{threeparttable}" _n
file write `texD1' "\end{table}" _n
file close `texD1'

/**********************************************************************
 Figure D.2: first-choice truth-telling over rounds
**********************************************************************/
use "$DER/analysis_sample.dta", clear

/* Equal weight to each of the seven participant types within a round. */
collapse (mean) top_choice_truth, by(treatment round id_in_group)
collapse (mean) top_choice_truth, by(treatment round)

save "$DER/figureD2_first_choice_truth_rounds.dta", replace
export delimited using "$DER/figureD2_first_choice_truth_rounds.csv", replace

twoway ///
    (connected top_choice_truth round if treatment==3, ///
        lcolor("`da_no'") mcolor("`da_no'") msymbol(circle) lpattern(solid)) ///
    (connected top_choice_truth round if treatment==2, ///
        lcolor("`da_str'") mcolor("`da_str'") msymbol(triangle) lpattern(solid)) ///
    (connected top_choice_truth round if treatment==1, ///
        lcolor("`da_prob'") mcolor("`da_prob'") msymbol(square) lpattern(solid)), ///
    xlabel(1(1)10) ylabel(.3(.1).7, angle(horizontal) glcolor(gs14)) ///
    yscale(range(.3 .7)) xtitle("Round") ytitle("First-choice truth-telling") ///
    title("DA", size(medsmall)) ///
    legend(order(1 "No appeals" 2 "Strict" 3 "Probabilistic") ///
        position(6) cols(3) size(small)) ///
    graphregion(color(white)) bgcolor(white) name(da_top_round, replace)

twoway ///
    (connected top_choice_truth round if treatment==6, ///
        lcolor("`ia_no'") mcolor("`ia_no'") msymbol(circle) lpattern(solid)) ///
    (connected top_choice_truth round if treatment==5, ///
        lcolor("`ia_str'") mcolor("`ia_str'") msymbol(triangle) lpattern(solid)) ///
    (connected top_choice_truth round if treatment==4, ///
        lcolor("`ia_prob'") mcolor("`ia_prob'") msymbol(square) lpattern(solid)), ///
    xlabel(1(1)10) ylabel(.3(.1).7, angle(horizontal) glcolor(gs14)) ///
    yscale(range(.3 .7)) xtitle("Round") ytitle("") ///
    title("IA", size(medsmall)) ///
    legend(order(1 "No appeals" 2 "Strict" 3 "Probabilistic") ///
        position(6) cols(3) size(small)) ///
    graphregion(color(white)) bgcolor(white) name(ia_top_round, replace)

graph combine da_top_round ia_top_round, cols(2) ycommon imargin(tiny) graphregion(color(white))
graph export "$FIG/figureD2_first_choice_truth_rounds.pdf", replace
graph export "$FIG/figureD2_first_choice_truth_rounds.png", width(2400) replace

/**********************************************************************
 D.3 Efficiency measured in experimental points
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile figD3data
tempname figD3post
postfile `figD3post' byte treatment double mean se lo hi using `figD3data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress welfare_points if treatment == `t', vce(cluster session)
    local m = _b[_cons]
    local s = _se[_cons]
    post `figD3post' (`t') (`m') (`s') (`m' - 1.96*`s') (`m' + 1.96*`s')
}
postclose `figD3post'
use `figD3data', clear
save "$DER/figureD3_points.dta", replace
export delimited using "$DER/figureD3_points.csv", replace

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
    (scatter hi xpos, msymbol(none) mlabel(mean) mlabformat(%4.2f) ///
        mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(0(2)12, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 11)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Average points") ///
    legend(off) graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figureD3_points.pdf", replace
graph export "$FIG/figureD3_points.png", width(2400) replace

/**********************************************************************
 Figure D.4: share unassigned
**********************************************************************/
use "$DER/analysis_sample.dta", clear
gen byte unassigned = assigned_rank == 4

tempfile figD4data
tempname figD4post
postfile `figD4post' byte treatment double mean se lo hi using `figD4data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress unassigned if treatment == `t', vce(cluster session)
    local m = _b[_cons]
    local s = _se[_cons]
    post `figD4post' (`t') (`m') (`s') (`m' - 1.96*`s') (`m' + 1.96*`s')
}
postclose `figD4post'
use `figD4data', clear
save "$DER/figureD4_unassigned.dta", replace
export delimited using "$DER/figureD4_unassigned.csv", replace

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
    (scatter hi xpos, msymbol(none) mlabel(mean) mlabformat(%4.2f) ///
        mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(0(.05).20, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 .20)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Share unassigned") ///
    legend(off) graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figureD4_unassigned.pdf", replace
graph export "$FIG/figureD4_unassigned.png", width(2400) replace

/**********************************************************************
 Table D.3: impact of appeals on experimental points
**********************************************************************/
use "$DER/analysis_sample.dta", clear

tempfile tableD2data
tempname tableD2post
postfile `tableD2post' byte row spec double estimate se pvalue long N using `tableD2data', replace

forvalues spec = 1/4 {
    if `spec' == 1 quietly regress welfare_points i.treatment, vce(cluster session)
    if `spec' == 2 quietly regress welfare_points i.treatment i.round, vce(cluster session)
    if `spec' == 3 quietly regress welfare_points i.treatment i.round i.id_in_group, vce(cluster session)
    if `spec' == 4 quietly regress welfare_points i.treatment i.round i.id_in_group age female risk_aversion, vce(cluster session)
    local NN = e(N)
    if `spec' < 4 assert `NN' == 10195
    if `spec' == 4 assert `NN' == 10185

    quietly margins treatment, post

    quietly lincom 5.treatment - 6.treatment
    post `tableD2post' (1) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 4.treatment - 6.treatment
    post `tableD2post' (2) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 2.treatment - 3.treatment
    post `tableD2post' (3) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom 1.treatment - 3.treatment
    post `tableD2post' (4) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')

    /* Positive values mean that appeals widen IA's points advantage. */
    quietly lincom (5.treatment - 2.treatment) - (6.treatment - 3.treatment)
    post `tableD2post' (5) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
    quietly lincom (4.treatment - 1.treatment) - (6.treatment - 3.treatment)
    post `tableD2post' (6) (`spec') (r(estimate)) (r(se)) (r(p)) (`NN')
}
postclose `tableD2post'
use `tableD2data', clear
save "$DER/tableD2_points_estimates.dta", replace
export delimited using "$DER/tableD2_points_estimates.csv", replace

local pointsrow1 "IA strict"
local pointsrow2 "IA probabilistic"
local pointsrow3 "DA strict"
local pointsrow4 "DA probabilistic"
local pointsrow5 "Strict appeals"
local pointsrow6 "Probabilistic appeals"

tempname texD2
file open `texD2' using "$TAB/tableD2_points.tex", write replace
file write `texD2' "\begin{table}[htbp]" _n
file write `texD2' "\centering" _n
file write `texD2' "\caption{Impact of appeals on experimental points}" _n
file write `texD2' "\label{tab:points_appeals}" _n
file write `texD2' "\begin{threeparttable}" _n
file write `texD2' "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} lcccc @{}}" _n
file write `texD2' "\toprule" _n
file write `texD2' "& \multicolumn{4}{c}{Specifications} \\" _n
file write `texD2' "& (1) & (2) & (3) & (4) \\" _n
file write `texD2' "\midrule" _n
file write `texD2' "\multicolumn{5}{l}{\textbf{Panel A. IA treatments}} \\" _n

forvalues r = 1/6 {
    if `r' == 3 file write `texD2' "\addlinespace" _n "\multicolumn{5}{l}{\textbf{Panel B. DA treatments}} \\" _n
    if `r' == 5 file write `texD2' "\addlinespace" _n "\multicolumn{5}{l}{\textbf{Panel C. Increase in IA's points advantage relative to no appeals}} \\" _n
    local line ""
    local seline ""
    forvalues s = 1/4 {
        quietly summarize estimate if row==`r' & spec==`s', meanonly
        local bb = r(mean)
        quietly summarize se if row==`r' & spec==`s', meanonly
        local ss = r(mean)
        quietly summarize pvalue if row==`r' & spec==`s', meanonly
        local pp = r(mean)
        if abs(`bb') < .005 local bb = 0
        quietly texcell, b(`bb') se(`ss') p(`pp') digits(2)
        local line "`line' & `r(coef)'"
        local seline "`seline' & `r(se)'"
    }
    file write `texD2' "`pointsrow`r''`line' \\" _n
    file write `texD2' "`seline' \\" _n
}

file write `texD2' "\addlinespace" _n
file write `texD2' "Round effects & No & Yes & Yes & Yes \\" _n
file write `texD2' "Participant-type effects & No & No & Yes & Yes \\" _n
file write `texD2' "Demographics + risk att. & No & No & No & Yes \\" _n
file write `texD2' "\midrule" _n
file write `texD2' "Observations & 10{,}195 & 10{,}195 & 10{,}195 & 10{,}185 \\" _n
file write `texD2' "Matching groups & 59 & 59 & 59 & 59 \\" _n
file write `texD2' "\bottomrule" _n
file write `texD2' "\end{tabular*}" _n
file write `texD2' "\begin{tablenotes}[flushleft]" _n
file write `texD2' "\footnotesize" _n
file write `texD2' "\item Notes. \(^{***}p<0.01\), \(^{**}p<0.05\), \(^{*}p<0.10\). Entries are adjusted differences in experimental points from linear regressions. Standard errors are clustered at the matching-group level. The baselines in Panels A and B are the corresponding mechanisms without appeals. Panel C reports \((\text{IA appeal}-\text{DA appeal})-(\text{IA no appeals}-\text{DA no appeals})\), so positive values indicate that appeals widen IA's points advantage. Demographics and risk attitudes are age, gender, and risk aversion." _n
file write `texD2' "\end{tablenotes}" _n
file write `texD2' "\end{threeparttable}" _n
file write `texD2' "\end{table}" _n
file close `texD2'

/**********************************************************************
 D.4 Mean number of strict blocking pairs
**********************************************************************/
use "$DER/market_rounds.dta", clear
assert _N == 1435

/* Weight every independent matching group equally, as in Figure 4. */
collapse (mean) strict_bp_sub strict_bp_true, by(treatment session)

tempfile figD5data
tempname figD5post
postfile `figD5post' byte treatment double sub_mean sub_se sub_lo sub_hi true_mean true_se true_lo true_hi using `figD5data', replace
foreach t in 3 2 1 6 5 4 {
    quietly regress strict_bp_sub if treatment == `t'
    local m1 = _b[_cons]
    local s1 = _se[_cons]
    quietly regress strict_bp_true if treatment == `t'
    local m2 = _b[_cons]
    local s2 = _se[_cons]
    post `figD5post' (`t') (`m1') (`s1') (`m1' - 1.96*`s1') (`m1' + 1.96*`s1') ///
        (`m2') (`s2') (`m2' - 1.96*`s2') (`m2' + 1.96*`s2')
}
postclose `figD5post'
use `figD5data', clear
save "$DER/figureD5_blocking_pairs.dta", replace
export delimited using "$DER/figureD5_blocking_pairs.csv", replace

gen byte xpos = .
replace xpos = 1 if treatment == 3
replace xpos = 2 if treatment == 2
replace xpos = 3 if treatment == 1
replace xpos = 5 if treatment == 6
replace xpos = 6 if treatment == 5
replace xpos = 7 if treatment == 4
gen double x_sub = xpos - .18
gen double x_true = xpos + .18

twoway ///
    (bar sub_mean x_sub, barwidth(.34) color("31 119 180")) ///
    (bar true_mean x_true, barwidth(.34) color("255 127 14")) ///
    (rcap sub_hi sub_lo x_sub, lcolor(black) lwidth(medthin)) ///
    (rcap true_hi true_lo x_true, lcolor(black) lwidth(medthin)) ///
    (scatter sub_hi x_sub, msymbol(none) mlabel(sub_mean) mlabformat(%4.2f) ///
        mlabposition(12) mlabgap(2) mlabcolor(black)) ///
    (scatter true_hi x_true, msymbol(none) mlabel(true_mean) mlabformat(%4.2f) ///
        mlabposition(12) mlabgap(2) mlabcolor(black)), ///
    xline(4, lcolor(gs12) lwidth(thin)) ///
    xlabel(`xlabel6', noticks labsize(small)) ///
    ylabel(0(.5)2.5, angle(horizontal) glcolor(gs14)) ///
    yscale(range(0 2.35)) xscale(range(.5 7.5)) ///
    xtitle("") ytitle("Mean strict blocking pairs") ///
    legend(order(1 "Submitted preferences" 2 "Induced preferences") ///
        cols(2) position(6)) ///
    graphregion(color(white)) plotregion(margin(zero)) bgcolor(white)

graph export "$FIG/figureD5_blocking_pairs.pdf", replace
graph export "$FIG/figureD5_blocking_pairs.png", width(2400) replace

display as result "Appendix results completed."
