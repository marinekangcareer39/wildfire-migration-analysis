****************************************************
* A) FULL POST-DYNAMICS EVENT-STUDY (4-outcome set)
* - Treated: ever had p90 wildfire event during 2017q2–2023q1
* - Control: never had p90 wildfire event during sample (clean control)
* - Event time: rel_p90 = yq - wf_int90p_first_yq (quarters)
* - Window: leads -4,-3,-2 and lags 0..+8
* - Reference period: rel = -1 (omitted)
* - Spec: y_it = Σ_k β_k 1(rel=k)*Treated + ZIP FE + yq FE
* - SE: cluster(zip)
*
* Outputs:
*   (1) Four event-study plots (nettotal, netperm, inperm, outperm)
*   (2) CSV of coefficients for plotting / paper
****************************************************

clear all
set more off
version 18

****************************************************
* 0) PATHS / PACKAGES / SETTINGS
****************************************************
local DATAFILE "/Users/marine/Documents/Senior IS Final/Economics/Senior IS Data/Data Cleaning/FINAL_REGRESSION_TWFE_CA_2017q2_2023q1.dta"
local OUTDIR   "/Users/marine/Documents/Senior IS Final/Economics/Outputs"

cap mkdir "`OUTDIR'"

cap which esttab
if _rc ssc install estout, replace
cap which eststo
if _rc ssc install estout, replace

local minlead 4
local maxpost 8

local outcomes "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"
local mtitles  `" "Net total" "Net permanent" "In permanent" "Out permanent" "'

display "DATAFILE = `DATAFILE'"
display "OUTDIR   = `OUTDIR'"

****************************************************
* 1) LOAD + PANEL SET
****************************************************
use "`DATAFILE'", clear
isid zip yq
xtset zip yq

****************************************************
* 2) DEFINE EVER-TREATED (p90) + CLEAN CONTROL SAMPLE
****************************************************
capture drop wf90ever_treated
bys zip: egen byte wf90ever_treated = max(wf_int90p_event)
label var wf90ever_treated "Ever p90 event during sample (treated group)"

keep if inlist(wf90ever_treated,0,1)

****************************************************
* 3) BUILD EVENT TIME
****************************************************
capture confirm variable wf_int90p_first_yq
if _rc {
    di as error "wf_int90p_first_yq not found. STOP."
    exit 198
}

capture drop rel_p90
gen rel_p90 = yq - wf_int90p_first_yq
replace rel_p90 = . if wf90ever_treated==0
label var rel_p90 "Event time (quarters) relative to first p90 event"

****************************************************
* 4) CREATE EVENT-TIME DUMMIES
****************************************************
capture drop lead4 lead3 lead2
gen byte lead4 = (rel_p90==-4) if wf90ever_treated==1
gen byte lead3 = (rel_p90==-3) if wf90ever_treated==1
gen byte lead2 = (rel_p90==-2) if wf90ever_treated==1

replace lead4 = 0 if wf90ever_treated==0
replace lead3 = 0 if wf90ever_treated==0
replace lead2 = 0 if wf90ever_treated==0

label var lead4 "Lead -4"
label var lead3 "Lead -3"
label var lead2 "Lead -2"

forvalues k = 0/`maxpost' {
    capture drop post`k'
    gen byte post`k' = (rel_p90==`k') if wf90ever_treated==1
    replace post`k' = 0 if wf90ever_treated==0
    label var post`k' "Post +`k'"
}

****************************************************
* 5) BUILD REGRESSOR LIST
****************************************************
local es_terms "lead4 lead3 lead2"
forvalues k = 0/`maxpost' {
    local es_terms "`es_terms' post`k'"
}

****************************************************
* 6) COEFFICIENT STORAGE FOR CSV + PLOTS
****************************************************
tempname H
tempfile es_coefs

postfile `H' ///
    str28 outcome ///
    int rel ///
    double b se ll ul pret_p ///
    using `es_coefs', replace

****************************************************
* 7) RUN EVENT-STUDY REGRESSIONS + STORE COEFFICIENTS
****************************************************
foreach y of local outcomes {

    quietly xtreg `y' `es_terms' i.yq, fe vce(cluster zip)

    quietly test lead4 lead3 lead2
    local pret = r(p)

    foreach k in 4 3 2 {
        local term lead`k'
        local relv = -`k'
        quietly lincom `term'
        post `H' ("`y'") (`relv') (r(estimate)) (r(se)) (r(lb)) (r(ub)) (`pret')
    }

    forvalues k = 0/`maxpost' {
        local term post`k'
        quietly lincom `term'
        post `H' ("`y'") (`k') (r(estimate)) (r(se)) (r(lb)) (r(ub)) (`pret')
    }

    * reference period rel=-1
    post `H' ("`y'") (-1) (0) (0) (0) (0) (`pret')
}

postclose `H'

****************************************************
* 8) EXPORT CSV OF COEFFICIENTS
****************************************************
use `es_coefs', clear
sort outcome rel
keep if rel>=-`minlead' & rel<=`maxpost'
order outcome rel b se ll ul pret_p

export delimited using "`OUTDIR'/A_eventstudy_coefs_4outcomes.csv", replace
di as text "Saved CSV: `OUTDIR'/A_eventstudy_coefs_4outcomes.csv"

****************************************************
* 9) EVENT-STUDY PLOTS (4 PNG FILES)
****************************************************
local plotlist "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"

foreach y of local plotlist {
    preserve
        keep if outcome=="`y'"
        sort rel

        twoway ///
            (rcap ul ll rel) ///
            (connected b rel, msymbol(O)) ///
            , ///
            xline(-0.5, lpattern(dash)) ///
            yline(0, lpattern(solid)) ///
            title("Event-study: `y'") ///
            xtitle("Event time (quarters, ref = -1)") ///
            ytitle("Coefficient (vs rel = -1)") ///
            legend(off) ///
            graphregion(color(white)) ///
            plotregion(color(white))

        graph export "`OUTDIR'/A_eventstudy_`y'.png", replace
    restore
}

****************************************************
* 10) RELOAD ORIGINAL PANEL DATA FOR TABLE EXPORT
****************************************************
use "`DATAFILE'", clear
isid zip yq
xtset zip yq

capture drop wf90ever_treated
bys zip: egen byte wf90ever_treated = max(wf_int90p_event)
keep if inlist(wf90ever_treated,0,1)

capture drop rel_p90
gen rel_p90 = yq - wf_int90p_first_yq
replace rel_p90 = . if wf90ever_treated==0

capture drop lead4 lead3 lead2
gen byte lead4 = (rel_p90==-4) if wf90ever_treated==1
gen byte lead3 = (rel_p90==-3) if wf90ever_treated==1
gen byte lead2 = (rel_p90==-2) if wf90ever_treated==1

replace lead4 = 0 if wf90ever_treated==0
replace lead3 = 0 if wf90ever_treated==0
replace lead2 = 0 if wf90ever_treated==0

label var lead4 "Lead -4"
label var lead3 "Lead -3"
label var lead2 "Lead -2"

forvalues k = 0/`maxpost' {
    capture drop post`k'
    gen byte post`k' = (rel_p90==`k') if wf90ever_treated==1
    replace post`k' = 0 if wf90ever_treated==0
    label var post`k' "Post +`k'"
}

****************************************************
* 11) STORE 4 MODELS FOR TABLE EXPORT
****************************************************
local keepvars "lead4 lead3 lead2"
forvalues k = 0/`maxpost' {
    local keepvars "`keepvars' post`k'"
}

local LAB_ES ///
    coeflabels( ///
      lead4 "Lead -4" ///
      lead3 "Lead -3" ///
      lead2 "Lead -2" ///
      post0 "Post 0" ///
      post1 "Post +1" ///
      post2 "Post +2" ///
      post3 "Post +3" ///
      post4 "Post +4" ///
      post5 "Post +5" ///
      post6 "Post +6" ///
      post7 "Post +7" ///
      post8 "Post +8" ///
    )

eststo clear
local j = 0

foreach y of local outcomes {
    local ++j

    quietly xtreg `y' `keepvars' i.yq, fe vce(cluster zip)

    quietly test lead4 lead3 lead2
    estadd scalar pretrend_p = r(p)

    estadd local zip_fe  "Yes"
    estadd local qtr_fe  "Yes"
    estadd local clus_se "ZIP"

    eststo M`j'
}

****************************************************
* 12) EXPORT TABLE — RTF
****************************************************
esttab M1 M2 M3 M4 using "`OUTDIR'/Tbl_ES_PostDyn_Full.rtf", replace rtf ///
    keep(`keepvars') order(`keepvars') ///
    `LAB_ES' ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles') ///
    stats(N r2_w pretrend_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" ///
                 "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 0 0 0)) ///
    title("Event-study (Post-dynamics): Ever p90 wildfire event") ///
    nonotes

****************************************************
* 13) EXPORT TABLE — TEX
****************************************************
esttab M1 M2 M3 M4 using "`OUTDIR'/Tbl_ES_PostDyn_Full.tex", replace booktabs ///
    keep(`keepvars') order(`keepvars') ///
    `LAB_ES' ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles') ///
    stats(N r2_w pretrend_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" ///
                 "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 0 0 0)) ///
    title("Event-study (Post-dynamics): Ever p90 wildfire event") ///
    nonotes

****************************************************
* 14) DONE
****************************************************
di as text "DONE: all outputs saved to `OUTDIR'"
di as text "CSV : A_eventstudy_coefs_4outcomes.csv"
di as text "PNG : 4 event-study graphs"
di as text "RTF : Tbl_ES_PostDyn_Full.rtf"
di as text "TEX : Tbl_ES_PostDyn_Full.tex"
