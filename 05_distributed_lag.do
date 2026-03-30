****************************************************
* Distributed lag models with heterogeneity interactions
* using income and house-price split variables
*
* Outputs saved to OUTDIR:
*   - DL_interaction_results_<groupvar>.csv
*   - DL_cumulative_results_<groupvar>.csv
*   - DL_<groupvar>_PanelA_ln.rtf / .tex
*   - DL_<groupvar>_PanelB_raw1e6.rtf / .tex
****************************************************

clear all
set more off
version 18

****************************************************
* 0) PATHS / PACKAGES / SETTINGS
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

local outcomes "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"
local mtitles  `" "Net total" "Net permanent" "In permanent" "Out permanent" "'
local maxlag 8
local leadq  4

display "DATAFILE = `DATAFILE'"
display "OUTDIR   = `OUTDIR'"

****************************************************
* 1) LOAD DATA
****************************************************
use "`DATAFILE'", clear
isid zip yq
xtset zip yq

****************************************************
* 2) BUILD SPLIT VARIABLES IF NEEDED
****************************************************
capture confirm variable highincome
if _rc {
    capture drop inc_zip
    bys zip: egen double inc_zip = mean(median_income)
    quietly summarize inc_zip, detail

    capture drop highincome
    gen byte highincome = (inc_zip > r(p50)) if inc_zip < .
    label var highincome "Above-median income ZIP"
}

capture confirm variable highhouse
if _rc {
    capture drop house_zip
    bys zip: egen double house_zip = mean(median_house_price)
    quietly summarize house_zip, detail

    capture drop highhouse
    gen byte highhouse = (house_zip > r(p50)) if house_zip < .
    label var highhouse "Above-median house-price ZIP"
}

****************************************************
* 3) SCALE RAW INTENSITY
****************************************************
capture drop wf_zip_1e6
gen double wf_zip_1e6 = wf_zip * 1000000

label var ln_wf_zip  "Log wildfire intensity"
label var wf_zip_1e6 "Raw wildfire intensity × 1e6"

****************************************************
* 4) CREATE EXPLICIT LAG/LEAD VARIABLES ONCE
****************************************************

* ---- log intensity lags/leads
capture drop ln0 ln1 ln2 ln3 ln4 ln5 ln6 ln7 ln8 lnf4
gen double ln0  = ln_wf_zip
gen double ln1  = L1.ln_wf_zip
gen double ln2  = L2.ln_wf_zip
gen double ln3  = L3.ln_wf_zip
gen double ln4  = L4.ln_wf_zip
gen double ln5  = L5.ln_wf_zip
gen double ln6  = L6.ln_wf_zip
gen double ln7  = L7.ln_wf_zip
gen double ln8  = L8.ln_wf_zip
gen double lnf4 = F4.ln_wf_zip

label var ln0  "Log intensity"
label var ln1  "Lag 1"
label var ln2  "Lag 2"
label var ln3  "Lag 3"
label var ln4  "Lag 4"
label var ln5  "Lag 5"
label var ln6  "Lag 6"
label var ln7  "Lag 7"
label var ln8  "Lag 8"
label var lnf4 "Lead 4"

* ---- raw intensity lags/leads
capture drop raw0 raw1 raw2 raw3 raw4 raw5 raw6 raw7 raw8 rawf4
gen double raw0  = wf_zip_1e6
gen double raw1  = L1.wf_zip_1e6
gen double raw2  = L2.wf_zip_1e6
gen double raw3  = L3.wf_zip_1e6
gen double raw4  = L4.wf_zip_1e6
gen double raw5  = L5.wf_zip_1e6
gen double raw6  = L6.wf_zip_1e6
gen double raw7  = L7.wf_zip_1e6
gen double raw8  = L8.wf_zip_1e6
gen double rawf4 = F4.wf_zip_1e6

label var raw0  "Raw intensity × 1e6"
label var raw1  "Lag 1"
label var raw2  "Lag 2"
label var raw3  "Lag 3"
label var raw4  "Lag 4"
label var raw5  "Lag 5"
label var raw6  "Lag 6"
label var raw7  "Lag 7"
label var raw8  "Lag 8"
label var rawf4 "Lead 4"

****************************************************
* 5) LOOP OVER SPLIT VARIABLES
****************************************************
foreach groupvar in highincome highhouse {

    di as text "=================================================="
    di as text "RUNNING HETEROGENEITY SPLIT: `groupvar'"
    di as text "=================================================="

    ************************************************
    * 5A) CREATE INTERACTION VARIABLES ONCE PER SPLIT
    ************************************************

    * ---- log intensity interactions
    capture drop ln0_g ln1_g ln2_g ln3_g ln4_g ln5_g ln6_g ln7_g ln8_g lnf4_g
    gen double ln0_g  = ln0  * `groupvar'
    gen double ln1_g  = ln1  * `groupvar'
    gen double ln2_g  = ln2  * `groupvar'
    gen double ln3_g  = ln3  * `groupvar'
    gen double ln4_g  = ln4  * `groupvar'
    gen double ln5_g  = ln5  * `groupvar'
    gen double ln6_g  = ln6  * `groupvar'
    gen double ln7_g  = ln7  * `groupvar'
    gen double ln8_g  = ln8  * `groupvar'
    gen double lnf4_g = lnf4 * `groupvar'

    label var ln0_g  "Log intensity × `groupvar'"
    label var ln1_g  "Lag 1 × `groupvar'"
    label var ln2_g  "Lag 2 × `groupvar'"
    label var ln3_g  "Lag 3 × `groupvar'"
    label var ln4_g  "Lag 4 × `groupvar'"
    label var ln5_g  "Lag 5 × `groupvar'"
    label var ln6_g  "Lag 6 × `groupvar'"
    label var ln7_g  "Lag 7 × `groupvar'"
    label var ln8_g  "Lag 8 × `groupvar'"
    label var lnf4_g "Lead 4 × `groupvar'"

    * ---- raw intensity interactions
    capture drop raw0_g raw1_g raw2_g raw3_g raw4_g raw5_g raw6_g raw7_g raw8_g rawf4_g
    gen double raw0_g  = raw0  * `groupvar'
    gen double raw1_g  = raw1  * `groupvar'
    gen double raw2_g  = raw2  * `groupvar'
    gen double raw3_g  = raw3  * `groupvar'
    gen double raw4_g  = raw4  * `groupvar'
    gen double raw5_g  = raw5  * `groupvar'
    gen double raw6_g  = raw6  * `groupvar'
    gen double raw7_g  = raw7  * `groupvar'
    gen double raw8_g  = raw8  * `groupvar'
    gen double rawf4_g = rawf4 * `groupvar'

    label var raw0_g  "Raw intensity × 1e6 × `groupvar'"
    label var raw1_g  "Lag 1 × `groupvar'"
    label var raw2_g  "Lag 2 × `groupvar'"
    label var raw3_g  "Lag 3 × `groupvar'"
    label var raw4_g  "Lag 4 × `groupvar'"
    label var raw5_g  "Lag 5 × `groupvar'"
    label var raw6_g  "Lag 6 × `groupvar'"
    label var raw7_g  "Lag 7 × `groupvar'"
    label var raw8_g  "Lag 8 × `groupvar'"
    label var rawf4_g "Lead 4 × `groupvar'"

    ************************************************
    * 5B) SET UP CSV STORAGE
    ************************************************
    tempname hcoef
    tempfile coef_tbl

    postfile `hcoef' ///
        str12 splitvar ///
        str12 intensity ///
        str25 outcome ///
        str8  group ///
        int   lag ///
        double b se p ///
        long N ///
        using `coef_tbl', replace

    tempname hcum
    tempfile cum_tbl

    postfile `hcum' ///
        str12 splitvar ///
        str12 intensity ///
        str25 outcome ///
        str8  group ///
        double cum04 cum04_p ///
        double cum08 cum08_p ///
        long N ///
        using `cum_tbl', replace

    ************************************************
    * 5C) BUILD CSV OUTPUTS — PANEL A (LOG)
    ************************************************
    foreach y of local outcomes {

        quietly xtreg `y' ///
            ln0 ln0_g ///
            ln1 ln1_g ///
            ln2 ln2_g ///
            ln3 ln3_g ///
            ln4 ln4_g ///
            ln5 ln5_g ///
            ln6 ln6_g ///
            ln7 ln7_g ///
            ln8 ln8_g ///
            lnf4 lnf4_g ///
            i.yq, fe vce(cluster zip)

        local N = e(N)

        * low group path
        forvalues k = 0/8 {
            quietly lincom ln`k'
            post `hcoef' ("`groupvar'") ("ln_wf_zip") ("`y'") ("low") (`k') ///
                (r(estimate)) (r(se)) (r(p)) (`N')

            quietly lincom ln`k' + ln`k'_g
            post `hcoef' ("`groupvar'") ("ln_wf_zip") ("`y'") ("high") (`k') ///
                (r(estimate)) (r(se)) (r(p)) (`N')
        }

        quietly lincom ln0 + ln1 + ln2 + ln3 + ln4
        local low04   = r(estimate)
        local low04_p = r(p)

        quietly lincom ln0 + ln1 + ln2 + ln3 + ln4 + ln5 + ln6 + ln7 + ln8
        local low08   = r(estimate)
        local low08_p = r(p)

        post `hcum' ("`groupvar'") ("ln_wf_zip") ("`y'") ("low") ///
            (`low04') (`low04_p') (`low08') (`low08_p') (`N')

        quietly lincom ///
            (ln0 + ln0_g) + (ln1 + ln1_g) + (ln2 + ln2_g) + (ln3 + ln3_g) + (ln4 + ln4_g)
        local high04   = r(estimate)
        local high04_p = r(p)

        quietly lincom ///
            (ln0 + ln0_g) + (ln1 + ln1_g) + (ln2 + ln2_g) + (ln3 + ln3_g) + (ln4 + ln4_g) + ///
            (ln5 + ln5_g) + (ln6 + ln6_g) + (ln7 + ln7_g) + (ln8 + ln8_g)
        local high08   = r(estimate)
        local high08_p = r(p)

        post `hcum' ("`groupvar'") ("ln_wf_zip") ("`y'") ("high") ///
            (`high04') (`high04_p') (`high08') (`high08_p') (`N')
    }

    ************************************************
    * 5D) BUILD CSV OUTPUTS — PANEL B (RAW)
    ************************************************
    foreach y of local outcomes {

        quietly xtreg `y' ///
            raw0 raw0_g ///
            raw1 raw1_g ///
            raw2 raw2_g ///
            raw3 raw3_g ///
            raw4 raw4_g ///
            raw5 raw5_g ///
            raw6 raw6_g ///
            raw7 raw7_g ///
            raw8 raw8_g ///
            rawf4 rawf4_g ///
            i.yq, fe vce(cluster zip)

        local N = e(N)

        forvalues k = 0/8 {
            quietly lincom raw`k'
            post `hcoef' ("`groupvar'") ("wf_zip_1e6") ("`y'") ("low") (`k') ///
                (r(estimate)) (r(se)) (r(p)) (`N')

            quietly lincom raw`k' + raw`k'_g
            post `hcoef' ("`groupvar'") ("wf_zip_1e6") ("`y'") ("high") (`k') ///
                (r(estimate)) (r(se)) (r(p)) (`N')
        }

        quietly lincom raw0 + raw1 + raw2 + raw3 + raw4
        local low04   = r(estimate)
        local low04_p = r(p)

        quietly lincom raw0 + raw1 + raw2 + raw3 + raw4 + raw5 + raw6 + raw7 + raw8
        local low08   = r(estimate)
        local low08_p = r(p)

        post `hcum' ("`groupvar'") ("wf_zip_1e6") ("`y'") ("low") ///
            (`low04') (`low04_p') (`low08') (`low08_p') (`N')

        quietly lincom ///
            (raw0 + raw0_g) + (raw1 + raw1_g) + (raw2 + raw2_g) + (raw3 + raw3_g) + (raw4 + raw4_g)
        local high04   = r(estimate)
        local high04_p = r(p)

        quietly lincom ///
            (raw0 + raw0_g) + (raw1 + raw1_g) + (raw2 + raw2_g) + (raw3 + raw3_g) + (raw4 + raw4_g) + ///
            (raw5 + raw5_g) + (raw6 + raw6_g) + (raw7 + raw7_g) + (raw8 + raw8_g)
        local high08   = r(estimate)
        local high08_p = r(p)

        post `hcum' ("`groupvar'") ("wf_zip_1e6") ("`y'") ("high") ///
            (`high04') (`high04_p') (`high08') (`high08_p') (`N')
    }

    postclose `hcoef'
    postclose `hcum'

    ************************************************
    * 5E) EXPORT CSV FILES
    ************************************************
    preserve
        use `coef_tbl', clear
        order splitvar intensity outcome group lag b se p N
        export delimited using "`OUTDIR'/DL_interaction_results_`groupvar'.csv", replace
    restore

    preserve
        use `cum_tbl', clear
        order splitvar intensity outcome group cum04 cum04_p cum08 cum08_p N
        export delimited using "`OUTDIR'/DL_cumulative_results_`groupvar'.csv", replace
    restore

    ************************************************
    * 5F) PANEL A TABLES — LOG INTENSITY
    ************************************************
    eststo clear
    local j = 0

    foreach y of local outcomes {
        local ++j

        quietly xtreg `y' ///
            ln0 ln0_g ///
            ln1 ln1_g ///
            ln2 ln2_g ///
            ln3 ln3_g ///
            ln4 ln4_g ///
            ln5 ln5_g ///
            ln6 ln6_g ///
            ln7 ln7_g ///
            ln8 ln8_g ///
            lnf4 lnf4_g ///
            i.yq, fe vce(cluster zip)

        estadd local zip_fe  "Yes"
        estadd local qtr_fe  "Yes"
        estadd local clus_se "ZIP"

        eststo m`j'
    }

    esttab m1 m2 m3 m4 using "`OUTDIR'/DL_`groupvar'_PanelA_ln.rtf", replace rtf ///
        keep(ln0 ln0_g ln1 ln1_g ln2 ln2_g ln3 ln3_g ln4 ln4_g ln5 ln5_g ln6 ln6_g ln7 ln7_g ln8 ln8_g lnf4 lnf4_g) ///
        order(ln0 ln0_g ln1 ln1_g ln2 ln2_g ln3 ln3_g ln4 ln4_g ln5 ln5_g ln6 ln6_g ln7 ln7_g ln8 ln8_g lnf4 lnf4_g) ///
        mtitles(`mtitles') ///
        label ///
        b(%9.6f) se(%9.6f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N r2_w zip_fe qtr_fe clus_se, ///
              labels("Observations" "Within R-squared" "ZIP FE" "Quarter FE" "Clustered SE") ///
              fmt(0 3 0 0 0)) ///
        title("Distributed Lag + Interaction (Panel A: ln_wf_zip, split=`groupvar')") ///
        nonotes

    esttab m1 m2 m3 m4 using "`OUTDIR'/DL_`groupvar'_PanelA_ln.tex", replace booktabs ///
        keep(ln0 ln0_g ln1 ln1_g ln2 ln2_g ln3 ln3_g ln4 ln4_g ln5 ln5_g ln6 ln6_g ln7 ln7_g ln8 ln8_g lnf4 lnf4_g) ///
        order(ln0 ln0_g ln1 ln1_g ln2 ln2_g ln3 ln3_g ln4 ln4_g ln5 ln5_g ln6 ln6_g ln7 ln7_g ln8 ln8_g lnf4 lnf4_g) ///
        mtitles(`mtitles') ///
        label ///
        b(%9.6f) se(%9.6f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N r2_w zip_fe qtr_fe clus_se, ///
              labels("Observations" "Within R-squared" "ZIP FE" "Quarter FE" "Clustered SE") ///
              fmt(0 3 0 0 0)) ///
        title("Distributed Lag + Interaction (Panel A: ln_wf_zip, split=`groupvar')") ///
        nonotes

    ************************************************
    * 5G) PANEL B TABLES — RAW INTENSITY × 1E6
    ************************************************
    eststo clear
    local j = 0

    foreach y of local outcomes {
        local ++j

        quietly xtreg `y' ///
            raw0 raw0_g ///
            raw1 raw1_g ///
            raw2 raw2_g ///
            raw3 raw3_g ///
            raw4 raw4_g ///
            raw5 raw5_g ///
            raw6 raw6_g ///
            raw7 raw7_g ///
            raw8 raw8_g ///
            rawf4 rawf4_g ///
            i.yq, fe vce(cluster zip)

        estadd local zip_fe  "Yes"
        estadd local qtr_fe  "Yes"
        estadd local clus_se "ZIP"

        eststo m`j'
    }

    esttab m1 m2 m3 m4 using "`OUTDIR'/DL_`groupvar'_PanelB_raw1e6.rtf", replace rtf ///
        keep(raw0 raw0_g raw1 raw1_g raw2 raw2_g raw3 raw3_g raw4 raw4_g raw5 raw5_g raw6 raw6_g raw7 raw7_g raw8 raw8_g rawf4 rawf4_g) ///
        order(raw0 raw0_g raw1 raw1_g raw2 raw2_g raw3 raw3_g raw4 raw4_g raw5 raw5_g raw6 raw6_g raw7 raw7_g raw8 raw8_g rawf4 rawf4_g) ///
        mtitles(`mtitles') ///
        label ///
        b(%12.4e) se(%12.4e) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N r2_w zip_fe qtr_fe clus_se, ///
              labels("Observations" "Within R-squared" "ZIP FE" "Quarter FE" "Clustered SE") ///
              fmt(0 3 0 0 0)) ///
        title("Distributed Lag + Interaction (Panel B: wf_zip × 1e6, split=`groupvar')") ///
        nonotes

    esttab m1 m2 m3 m4 using "`OUTDIR'/DL_`groupvar'_PanelB_raw1e6.tex", replace booktabs ///
        keep(raw0 raw0_g raw1 raw1_g raw2 raw2_g raw3 raw3_g raw4 raw4_g raw5 raw5_g raw6 raw6_g raw7 raw7_g raw8 raw8_g rawf4 rawf4_g) ///
        order(raw0 raw0_g raw1 raw1_g raw2 raw2_g raw3 raw3_g raw4 raw4_g raw5 raw5_g raw6 raw6_g raw7 raw7_g raw8 raw8_g rawf4 rawf4_g) ///
        mtitles(`mtitles') ///
        label ///
        b(%12.4e) se(%12.4e) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N r2_w zip_fe qtr_fe clus_se, ///
              labels("Observations" "Within R-squared" "ZIP FE" "Quarter FE" "Clustered SE") ///
              fmt(0 3 0 0 0)) ///
        title("Distributed Lag + Interaction (Panel B: wf_zip × 1e6, split=`groupvar')") ///
        nonotes
}

****************************************************
* 6) DONE
****************************************************
di as text "DONE: all CSV / RTF / TEX files saved to `OUTDIR'"
