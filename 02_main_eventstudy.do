****************************************************
* Main event-study specification with pre-trend check
****************************************************

clear all
set more off
version 18

****************************************************
* 0A) TABLE/FORMAT SETTINGS (publication-style)
****************************************************
cap which esttab
if _rc ssc install estout, replace

local BDEC  "4"
local SEDEC "4"
local STAR  "star(* 0.10 ** 0.05 *** 0.01)"
local SHOWCONS = 1

global root "YOUR_PROJECT_FOLDER"
global data "$root/data"
global output "$root/output"

local OUTDIR "$output"
cap mkdir "`OUTDIR'"

local OUTRTF "`OUTDIR'/Table_EventStudy_LeadsOnly.rtf"
local OUTTEX "`OUTDIR'/Table_EventStudy_LeadsOnly.tex"

****************************************************
* 0) LOAD + PANEL SET
****************************************************
use "$data/FINAL_REGRESSION_TWFE_CA_2017q2_2023q1.dta", clear

isid zip yq
xtset zip yq

label var wf_int90p_ever "Ever treated (p90 wildfire event)"

display "OUTDIR = `OUTDIR'"
display "OUTRTF = `OUTRTF'"
display "OUTTEX = `OUTTEX'"

****************************************************
* 1) DEFINE EVER-TREATED (p90) + CLEAN CONTROL SAMPLE
****************************************************
capture drop wf90ever_treated
bys zip: egen byte wf90ever_treated = max(wf_int90p_event)
label var wf90ever_treated "Ever p90 event during sample (treated group)"
keep if inlist(wf90ever_treated,0,1)

****************************************************
* 2) BUILD EVENT-TIME (relative to first p90 event) FOR LEADS ONLY
****************************************************
capture drop rel_p90
gen rel_p90 = yq - wf_int90p_first_yq
label var rel_p90 "Event time (quarters) relative to first p90 event"
replace rel_p90 = . if wf90ever_treated==0

****************************************************
* 3) LEADS (PRE-TREND) DUMMIES
****************************************************
capture drop lead4 lead3 lead2
gen byte lead4 = (rel_p90==-4) if wf90ever_treated==1
gen byte lead3 = (rel_p90==-3) if wf90ever_treated==1
gen byte lead2 = (rel_p90==-2) if wf90ever_treated==1
replace lead4 = 0 if wf90ever_treated==0
replace lead3 = 0 if wf90ever_treated==0
replace lead2 = 0 if wf90ever_treated==0

label var lead4 "Lead: -4 quarters"
label var lead3 "Lead: -3 quarters"
label var lead2 "Lead: -2 quarters"

****************************************************
* 4) ESTIMATION STORAGE
****************************************************
eststo clear

****************************************************
* 4.1) Net total
****************************************************
xtreg dv_rate_nettotal_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)

test lead4 lead3 lead2
estadd scalar pretrend_p = r(p)
estadd scalar r2_within = e(r2_within)
estadd local zip_fe "Yes"
estadd local qtr_fe "Yes"
eststo m1

****************************************************
* 4.2) Net perm
****************************************************
xtreg dv_rate_netperm_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)

test lead4 lead3 lead2
estadd scalar pretrend_p = r(p)
estadd scalar r2_within = e(r2_within)
estadd local zip_fe "Yes"
estadd local qtr_fe "Yes"
eststo m2

****************************************************
* 4.3) In perm
****************************************************
xtreg dv_rate_inperm_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)

test lead4 lead3 lead2
estadd scalar pretrend_p = r(p)
estadd scalar r2_within = e(r2_within)
estadd local zip_fe "Yes"
estadd local qtr_fe "Yes"
eststo m3

****************************************************
* 4.4) Out perm
****************************************************
xtreg dv_rate_outperm_w ///
    wf_int90p_ever lead4 lead3 lead2 ///
    i.yq, fe vce(cluster zip)

test lead4 lead3 lead2
estadd scalar pretrend_p = r(p)
estadd scalar r2_within = e(r2_within)
estadd local zip_fe "Yes"
estadd local qtr_fe "Yes"
eststo m4

****************************************************
* 5) EXPORT TABLES (Word draft + Overleaf final)
****************************************************
local KEEPVARS "wf_int90p_ever lead4 lead3 lead2"
if `SHOWCONS'==1 local KEEPVARS "`KEEPVARS' _cons"

* A) WORD/RTF
esttab m1 m2 m3 m4 using "`OUTRTF'", replace rtf ///
    keep(`KEEPVARS') ///
    b(%9.`BDEC'f) se(%9.`SEDEC'f) `STAR' ///
    label nonotes ///
    mtitles("Net total" "Net permanent" "In permanent" "Out permanent") ///
    stats(N r2_within pretrend_p zip_fe qtr_fe, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" "ZIP FE" "Quarter FE") ///
          fmt(0 3 3 0 0)) ///
    title("Event-study (Leads only): Ever p90 wildfire event")

* B) LaTeX
esttab m1 m2 m3 m4 using "`OUTTEX'", replace booktabs ///
    keep(`KEEPVARS') ///
    b(%9.`BDEC'f) se(%9.`SEDEC'f) `STAR' ///
    label nonotes ///
    mtitles("Net total" "Net permanent" "In permanent" "Out permanent") ///
    stats(N r2_within pretrend_p zip_fe qtr_fe, ///
          labels("Observations" "Within R-squared" "Pretrend p-value (F-test)" "ZIP FE" "Quarter FE") ///
          fmt(0 3 3 0 0)) ///
    title("Event-study (Leads only): Ever p90 wildfire event")

display "Saved RTF:"
display "`OUTRTF'"
display "Saved TEX:"
display "`OUTTEX'"
