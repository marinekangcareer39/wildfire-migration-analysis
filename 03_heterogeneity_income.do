****************************************************
* Income heterogeneity event-time DID with sanity checks,
* table exports, and coefficient graph
****************************************************
* Income heterogeneity event-time DID
* Full script: sanity checks, CSV, graph, RTF, and TeX tables
****************************************************

clear all
set more off
version 18

****************************************************
* 0) PATHS / PACKAGES
****************************************************
global root "YOUR_PROJECT_FOLDER"
global data "$root/data"
global output "$root/output"

local DATAFILE "$data/FINAL_REGRESSION_TWFE_CA_2017q2_2023q1.dta"
local OUTDIR   "$output"

cap mkdir "`OUTDIR'"

cap which esttab
if _rc ssc install estout, replace
cap which eststo
if _rc ssc install estout, replace

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

* Option A sample: ever-treated vs never-treated only
keep if inlist(wf90ever_treated,0,1)

di as text "================ SAMPLE CHECK ================"
count
tab wf90ever_treated, missing

****************************************************
* 3) BUILD EVENT-TIME (relative to first p90 event) FOR LEADS ONLY
****************************************************
capture drop rel_p90
gen rel_p90 = yq - wf_int90p_first_yq
label var rel_p90 "Event time (quarters) relative to first p90 event"

replace rel_p90 = . if wf90ever_treated==0

****************************************************
* 4) LEADS (PRE-TREND) DUMMIES
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

di as text "================ LEAD COUNTS (treated only) ================"
count if wf90ever_treated==1 & lead4==1
count if wf90ever_treated==1 & lead3==1
count if wf90ever_treated==1 & lead2==1

****************************************************
* 5) OPTIONAL BASELINE CHECKS
****************************************************
di as text "=================================================="
di as text "Outcome 1: dv_rate_nettotal_w"
di as text "=================================================="
count if missing(dv_rate_nettotal_w)
xtreg dv_rate_nettotal_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)
test lead4 lead3 lead2

di as text "=================================================="
di as text "Outcome 2: dv_rate_netperm_w"
di as text "=================================================="
count if missing(dv_rate_netperm_w)
xtreg dv_rate_netperm_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)
test lead4 lead3 lead2

di as text "=================================================="
di as text "Outcome 3: dv_rate_inperm_w"
di as text "=================================================="
count if missing(dv_rate_inperm_w)
xtreg dv_rate_inperm_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)
test lead4 lead3 lead2

di as text "=================================================="
di as text "Outcome 4: dv_rate_outperm_w"
di as text "=================================================="
count if missing(dv_rate_outperm_w)
xtreg dv_rate_outperm_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)
test lead4 lead3 lead2

****************************************************
* 6) OPTIONAL ESTIMATION-SAMPLE FLAG
****************************************************
capture drop es_ok
gen byte es_ok = 1
label var es_ok "Option A DID + lead test sample (no controls)"

****************************************************
* 7) INCOME SUBSAMPLE: DROP MISSING INCOME
****************************************************
di as text "================ INCOME SUBSAMPLE: DROP MISSING INCOME ZIPs ================"
count
count if missing(median_income)
drop if missing(median_income)
count

****************************************************
* 8) BUILD high_income (ZIP-level median split)
****************************************************
capture drop inc_zip
bys zip: egen double inc_zip = mean(median_income)

bys zip: egen double inc_zip_sd = sd(inc_zip)
summ inc_zip_sd, detail
drop inc_zip_sd

quietly summarize inc_zip, detail
local inc_median = r(p50)

capture drop high_income
gen byte high_income = (inc_zip > `inc_median') if inc_zip < .
label var high_income "Above-median income ZIP (median split across ZIPs)"

di as text "================ INCOME MEDIAN USED (across ZIPs) ================"
di as result "Median(inc_zip) = `inc_median'"

****************************************************
* 9) SANITY CHECKS — GROUP SIZE, TREATED SHARE, LEAD COUNTS, DV MISSINGNESS
****************************************************
di as text "================ INCOME GROUP COUNTS (OBS) ================"
tab high_income, missing

di as text "================ INCOME GROUP COUNTS (ZIPs) ================"
bys zip: gen byte onezip = (_n==1)
tab high_income if onezip==1, missing
drop onezip

di as text "================ TREATED SHARE BY INCOME GROUP (ZIP-level) ================"
bys zip: egen byte wf90ever_treated_zip = max(wf90ever_treated)
bys zip: gen byte onezip2 = (_n==1)
tab wf90ever_treated_zip high_income if onezip2==1, missing
drop onezip2 wf90ever_treated_zip

di as text "================ LEAD COUNTS (TREATED ONLY) BY INCOME GROUP ================"
count if wf90ever_treated==1 & high_income==0 & lead4==1
count if wf90ever_treated==1 & high_income==0 & lead3==1
count if wf90ever_treated==1 & high_income==0 & lead2==1
count if wf90ever_treated==1 & high_income==1 & lead4==1
count if wf90ever_treated==1 & high_income==1 & lead3==1
count if wf90ever_treated==1 & high_income==1 & lead2==1

di as text "================ DV MISSINGNESS BY INCOME GROUP (winsorized) ================"
foreach y in dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w {
    di as text "Outcome: `y'"
    count if high_income==0 & missing(`y')
    count if high_income==1 & missing(`y')
}

****************************************************
* 10) CSV SUMMARY EXTRACTION SETUP
****************************************************
tempname Hinc
tempfile inctbl

postfile `Hinc' ///
    str12 group ///
    str24 outcome ///
    double b_wf se_wf p_wf ///
    double lead_p ///
    double N ///
    double G ///
    using `inctbl', replace

****************************************************
* 11) RUN EVENT-TIME DID BY INCOME GROUP
****************************************************
local outcomes "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"

foreach g in 0 1 {

    if `g'==0 local gname "low_income"
    if `g'==1 local gname "high_income"

    di as text "##################################################"
    di as text "INCOME HETEROGENEITY: GROUP = `gname'"
    di as text "##################################################"

    foreach y of local outcomes {

        di as text "--------------------------------------------------"
        di as text "Outcome: `y' | Group: `gname'"
        di as text "--------------------------------------------------"

        quietly xtreg `y' ///
            wf_int90p_ever lead4 lead3 lead2 ///
            i.yq if high_income==`g', fe vce(cluster zip)

        local b  = _b[wf_int90p_ever]
        local se = _se[wf_int90p_ever]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))

        quietly test lead4 lead3 lead2
        local lp = r(p)

        local nobs = e(N)
        local ng   = e(N_g)

        post `Hinc' ///
            ("`gname'") ///
            ("`y'") ///
            (`b') (`se') (`p') ///
            (`lp') ///
            (`nobs') ///
            (`ng')
    }
}
postclose `Hinc'

****************************************************
* 12) EXPORT CSV SUMMARY
****************************************************
preserve
    use `inctbl', clear
    order group outcome b_wf se_wf p_wf lead_p N G
    label var group   "Group"
    label var outcome "Outcome"
    label var b_wf    "Coef: wf_int90p_ever"
    label var se_wf   "SE: wf_int90p_ever"
    label var p_wf    "p-value: wf_int90p_ever"
    label var lead_p  "p-value: joint leads (lead4 lead3 lead2)"
    label var N       "Obs used (e(N))"
    label var G       "# ZIP groups (e(N_g))"

    export delimited using "`OUTDIR'/Income_Heterogeneity_EventStudy_Table.csv", replace
restore

di as text "Saved CSV: `OUTDIR'/Income_Heterogeneity_EventStudy_Table.csv"

****************************************************
* 13) GRAPH — HOUSE-STYLE BAR GRAPH + 95% CI
****************************************************
preserve
    use `inctbl', clear

    gen double ub = b_wf + 1.96*se_wf
    gen double lb = b_wf - 1.96*se_wf

    gen order = .
    replace order = 1 if group=="low_income"  & outcome=="dv_rate_nettotal_w"
    replace order = 2 if group=="low_income"  & outcome=="dv_rate_netperm_w"
    replace order = 3 if group=="low_income"  & outcome=="dv_rate_inperm_w"
    replace order = 4 if group=="low_income"  & outcome=="dv_rate_outperm_w"
    replace order = 5 if group=="high_income" & outcome=="dv_rate_nettotal_w"
    replace order = 6 if group=="high_income" & outcome=="dv_rate_netperm_w"
    replace order = 7 if group=="high_income" & outcome=="dv_rate_inperm_w"
    replace order = 8 if group=="high_income" & outcome=="dv_rate_outperm_w"

    sort order
    gen x = order

    twoway ///
        (bar b_wf x, base(0) barwidth(0.65)) ///
        (rcap ub lb x) ///
        , ///
        xlabel(1 "Low | Net total" ///
               2 "Low | Net perm" ///
               3 "Low | In perm" ///
               4 "Low | Out perm" ///
               5 "High | Net total" ///
               6 "High | Net perm" ///
               7 "High | In perm" ///
               8 "High | Out perm", angle(45) labsize(medsmall)) ///
        yline(0, lpattern(dash)) ///
        xtitle("") ///
        ytitle("Coefficient on wf_int90p_ever") ///
        title("Income heterogeneity: DID effect by group/outcome") ///
        note("Bars = coefficients; caps = 95% CI. Event-time DID (Option A), leads included.", size(small)) ///
        legend(off) ///
        graphregion(color(white)) ///
        plotregion(color(white))

    graph export "`OUTDIR'/Income_Heterogeneity_wfcoef.png", replace
restore

di as text "Saved graph: `OUTDIR'/Income_Heterogeneity_wfcoef.png"

****************************************************
* 14) JOURNAL-STYLE TABLE EXPORTS (RTF + TEX)
****************************************************
label var wf_int90p_ever "Ever p90 wildfire event"
label var lead4          "Lead -4"
label var lead3          "Lead -3"
label var lead2          "Lead -2"

local outcomes "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"
local mtitles  `" "Net total" "Net permanent" "In permanent" "Out permanent" "'

eststo clear

****************************************************
* 14.1) STORE LOW-INCOME MODELS
****************************************************
local j = 0
foreach y of local outcomes {
    local ++j

    quietly xtreg `y' ///
        wf_int90p_ever lead4 lead3 lead2 ///
        i.yq if high_income==0, fe vce(cluster zip)

    quietly test lead4 lead3 lead2
    estadd scalar pretrend_p = r(p)
    estadd scalar r2_within  = e(r2_within)

    estadd local zip_fe  "Yes"
    estadd local qtr_fe  "Yes"
    estadd local clus_se "ZIP"

    eststo L`j'
}

****************************************************
* 14.2) STORE HIGH-INCOME MODELS
****************************************************
local j = 0
foreach y of local outcomes {
    local ++j

    quietly xtreg `y' ///
        wf_int90p_ever lead4 lead3 lead2 ///
        i.yq if high_income==1, fe vce(cluster zip)

    quietly test lead4 lead3 lead2
    estadd scalar pretrend_p = r(p)
    estadd scalar r2_within  = e(r2_within)

    estadd local zip_fe  "Yes"
    estadd local qtr_fe  "Yes"
    estadd local clus_se "ZIP"

    eststo H`j'
}

local M_LOW  "L1 L2 L3 L4"
local M_HIGH "H1 H2 H3 H4"

****************************************************
* 14.3) EXPORT LOW-INCOME TABLE
****************************************************
esttab `M_LOW' using "`OUTDIR'/Tbl_ES_IncSplit_Low.rtf", replace rtf ///
    keep(wf_int90p_ever lead4 lead3 lead2) ///
    order(wf_int90p_ever lead4 lead3 lead2) ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles') ///
    stats(N r2_within pretrend_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" ///
                 "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 0 0 0)) ///
    title("Event-study estimates (Leads only): Low-income ZIP codes") ///
    nonotes

esttab `M_LOW' using "`OUTDIR'/Tbl_ES_IncSplit_Low.tex", replace booktabs ///
    keep(wf_int90p_ever lead4 lead3 lead2) ///
    order(wf_int90p_ever lead4 lead3 lead2) ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles') ///
    stats(N r2_within pretrend_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" ///
                 "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 0 0 0)) ///
    title("Event-study estimates (Leads only): Low-income ZIP codes") ///
    nonotes

****************************************************
* 14.4) EXPORT HIGH-INCOME TABLE
****************************************************
esttab `M_HIGH' using "`OUTDIR'/Tbl_ES_IncSplit_High.rtf", replace rtf ///
    keep(wf_int90p_ever lead4 lead3 lead2) ///
    order(wf_int90p_ever lead4 lead3 lead2) ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles') ///
    stats(N r2_within pretrend_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" ///
                 "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 0 0 0)) ///
    title("Event-study estimates (Leads only): High-income ZIP codes") ///
    nonotes

esttab `M_HIGH' using "`OUTDIR'/Tbl_ES_IncSplit_High.tex", replace booktabs ///
    keep(wf_int90p_ever lead4 lead3 lead2) ///
    order(wf_int90p_ever lead4 lead3 lead2) ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles') ///
    stats(N r2_within pretrend_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" ///
                 "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 0 0 0)) ///
    title("Event-study estimates (Leads only): High-income ZIP codes") ///
    nonotes

****************************************************
* 15) DONE
****************************************************
di as text "DONE: saved all outputs to `OUTDIR'"
di as text "CSV : Income_Heterogeneity_EventStudy_Table.csv"
di as text "PNG : Income_Heterogeneity_wfcoef.png"
di as text "RTF : Tbl_ES_IncSplit_Low.rtf, Tbl_ES_IncSplit_High.rtf"
di as text "TEX : Tbl_ES_IncSplit_Low.tex, Tbl_ES_IncSplit_High.tex"
