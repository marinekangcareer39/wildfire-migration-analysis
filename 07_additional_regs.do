*****************************************************
* STEP 2–8 (FULL SAMPLE) — DISTRIBUTED LAG
* TEX + RTF + CSV + PNG ALL SAVED TO ONE FOLDER
*****************************************************

clear all
set more off
version 18

****************************************************
* 0) PATHS / SETTINGS
****************************************************
local datafile "/Users/marine/Documents/Senior IS Final/Economics/Senior IS Data/Data Cleaning/FINAL_REGRESSION_TWFE_CA_2017q2_2023q1.dta"

local OUTDIR "/Users/marine/Documents/Senior IS Final/Economics/Outputs"
cap mkdir "`OUTDIR'"

local figdir "`OUTDIR'"

local intensities "ln_wf_zip wf_zip"
local outcomes    "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"
local maxlag 8
local leadq  4

****************************************************
* 0A) esttab/eststo
****************************************************
cap which esttab
if _rc ssc install estout, replace
cap which eststo
if _rc ssc install estout, replace

display "OUTDIR = `OUTDIR'"

****************************************************
* 1) LOAD + PANEL SET
****************************************************
use "`datafile'", clear
isid zip yq
xtset zip yq

****************************************************
* 2) BASIC SANITY CHECKS
****************************************************
di as text "================ FULL SAMPLE CHECK ================"
count
xtdescribe

di as text "================ MISSING CHECK: OUTCOMES ================"
foreach y of local outcomes {
    capture confirm variable `y'
    if _rc {
        di as error "ERROR: outcome variable `y' not found in data. Stop."
        exit 111
    }
    count if missing(`y')
}

di as text "================ MISSING CHECK: INTENSITIES ================"
foreach x of local intensities {
    capture confirm variable `x'
    if _rc {
        di as error "ERROR: intensity variable `x' not found in data. Stop."
        exit 111
    }
    count if missing(`x')
}

di as text "================ INTENSITY NONNEGATIVITY CHECK (wf_zip) ================"
capture confirm variable wf_zip
if !_rc {
    count if wf_zip < 0 & wf_zip != .
}

di as text "================ QUICK CHECK: HOW OFTEN IS wf_zip ZERO? ================"
capture confirm variable wf_zip
if !_rc {
    count if wf_zip == 0
    count if wf_zip > 0
}

****************************************************
* 3) USABLE OBS FLAGS
****************************************************
capture drop dl_ok_ln dl_ok_raw
gen byte dl_ok_ln  = 1
gen byte dl_ok_raw = 1
label var dl_ok_ln  "Usable for L0..L8 & F4 using ln_wf_zip (nonmissing terms)"
label var dl_ok_raw "Usable for L0..L8 & F4 using wf_zip (nonmissing terms)"

replace dl_ok_ln = 0 if missing(ln_wf_zip) ///
    | missing(L1.ln_wf_zip) | missing(L2.ln_wf_zip) | missing(L3.ln_wf_zip) | missing(L4.ln_wf_zip) ///
    | missing(L5.ln_wf_zip) | missing(L6.ln_wf_zip) | missing(L7.ln_wf_zip) | missing(L8.ln_wf_zip) ///
    | missing(F`leadq'.ln_wf_zip)

replace dl_ok_raw = 0 if missing(wf_zip) ///
    | missing(L1.wf_zip) | missing(L2.wf_zip) | missing(L3.wf_zip) | missing(L4.wf_zip) ///
    | missing(L5.wf_zip) | missing(L6.wf_zip) | missing(L7.wf_zip) | missing(L8.wf_zip) ///
    | missing(F`leadq'.wf_zip)

di as text "================ USABLE OBS CHECK: ln_wf_zip ================"
tab dl_ok_ln, missing
di as text "================ USABLE OBS CHECK: wf_zip ================"
tab dl_ok_raw, missing

****************************************************
* 4) PULL + LEAD TEST SUMMARY TABLE
****************************************************
tempname hpull
tempfile pull_tbl
postfile `hpull' str12 intensity str22 outcome ///
    double cum04 cum04_se cum04_p ///
    double cum08 cum08_se cum08_p ///
    double leadp ///
    long N using `pull_tbl', replace

foreach x of local intensities {
    foreach y of local outcomes {

        quietly xtreg `y' ///
            `x' L1.`x' L2.`x' L3.`x' L4.`x' ///
            L5.`x' L6.`x' L7.`x' L8.`x' ///
            F`leadq'.`x' ///
            i.yq, fe vce(cluster zip)

        local N = e(N)

        quietly lincom `x' + L1.`x' + L2.`x' + L3.`x' + L4.`x'
        local c04 = r(estimate)
        local s04 = r(se)
        local p04 = r(p)

        quietly lincom `x' + L1.`x' + L2.`x' + L3.`x' + L4.`x' ///
                       + L5.`x' + L6.`x' + L7.`x' + L8.`x'
        local c08 = r(estimate)
        local s08 = r(se)
        local p08 = r(p)

        quietly test F`leadq'.`x'
        local lp = r(p)

        post `hpull' ("`x'") ("`y'") ///
            (`c04') (`s04') (`p04') ///
            (`c08') (`s08') (`p08') ///
            (`lp') ///
            (`N')
    }
}
postclose `hpull'

preserve
    use `pull_tbl', clear
    order intensity outcome cum04 cum04_se cum04_p cum08 cum08_se cum08_p leadp N
    export delimited using "`OUTDIR'/Step2_5_Pull_Lead_Summary.csv", replace
restore
di as text "Saved: `OUTDIR'/Step2_5_Pull_Lead_Summary.csv"

****************************************************
* 5) DISTRIBUTED LAG COEFFICIENT TABLE
****************************************************
tempname hdl
tempfile dl_tbl
postfile `hdl' str12 intensity str22 outcome ///
    int k str6 term ///
    double b se p ///
    long N using `dl_tbl', replace

foreach x of local intensities {
    foreach y of local outcomes {

        quietly xtreg `y' ///
            `x' L1.`x' L2.`x' L3.`x' L4.`x' ///
            L5.`x' L6.`x' L7.`x' L8.`x' ///
            F`leadq'.`x' ///
            i.yq, fe vce(cluster zip)

        local df = e(df_r)
        local N  = e(N)

        forvalues kk = 0/`maxlag' {
            if `kk'==0 local termname "`x'"
            else       local termname "L`kk'.`x'"

            capture scalar bb = _b[`termname']
            if _rc==0 {
                scalar ss = _se[`termname']
                scalar tt = bb/ss
                scalar pp = 2*ttail(`df', abs(tt))
                post `hdl' ("`x'") ("`y'") (`kk') ("L`kk'") (bb) (ss) (pp) (`N')
            }
            else {
                post `hdl' ("`x'") ("`y'") (`kk') ("L`kk'") (.) (.) (.) (`N')
            }
        }

        local leadterm "F`leadq'.`x'"
        capture scalar bb = _b[`leadterm']
        if _rc==0 {
            scalar ss = _se[`leadterm']
            scalar tt = bb/ss
            scalar pp = 2*ttail(`df', abs(tt))
            post `hdl' ("`x'") ("`y'") (-`leadq') ("F`leadq'") (bb) (ss) (pp) (`N')
        }
        else {
            post `hdl' ("`x'") ("`y'") (-`leadq') ("F`leadq'") (.) (.) (.) (`N')
        }
    }
}
postclose `hdl'

preserve
    use `dl_tbl', clear
    order intensity outcome k term b se p N
    export delimited using "`OUTDIR'/Step2_5_DL_CoefTable.csv", replace
restore
di as text "Saved: `OUTDIR'/Step2_5_DL_CoefTable.csv"

****************************************************
* 6) CUMULATIVE PATH TABLE
****************************************************
tempname hcum
tempfile cum_tbl
postfile `hcum' str12 intensity str22 outcome ///
    int h ///
    double cum cum_se cum_p ///
    double leadp ///
    long N using `cum_tbl', replace

foreach x of local intensities {
    foreach y of local outcomes {

        quietly xtreg `y' ///
            `x' L1.`x' L2.`x' L3.`x' L4.`x' ///
            L5.`x' L6.`x' L7.`x' L8.`x' ///
            F`leadq'.`x' ///
            i.yq, fe vce(cluster zip)

        local N = e(N)

        quietly test F`leadq'.`x'
        local lp = r(p)

        forvalues hh = 0/`maxlag' {
            local expr "`x'"
            if `hh' >= 1 {
                forvalues kk = 1/`hh' {
                    local expr "`expr' + L`kk'.`x'"
                }
            }

            quietly lincom `expr'
            local cc = r(estimate)
            local ss = r(se)
            local pp = r(p)

            post `hcum' ("`x'") ("`y'") (`hh') (`cc') (`ss') (`pp') (`lp') (`N')
        }
    }
}
postclose `hcum'

preserve
    use `cum_tbl', clear
    order intensity outcome h cum cum_se cum_p leadp N
    export delimited using "`OUTDIR'/Step2_5_CumPath.csv", replace
restore
di as text "Saved: `OUTDIR'/Step2_5_CumPath.csv"

****************************************************
* 7A) Distributed-lag coefficient figures
****************************************************
preserve
    import delimited using "`OUTDIR'/Step2_5_DL_CoefTable.csv", clear

    keep if k>=0 & k<=8

    gen ub = b + 1.96*se
    gen lb = b - 1.96*se

    levelsof intensity, local(ints)
    foreach x of local ints {
        levelsof outcome if intensity=="`x'", local(outs)
        foreach y of local outs {

            twoway ///
                (rcap ub lb k if intensity=="`x'" & outcome=="`y'") ///
                (connected b k if intensity=="`x'" & outcome=="`y'"), ///
                yline(0) ///
                xtitle("Lag k (quarters)") ///
                ytitle("Coefficient") ///
                title("Distributed lag: `y' on `x'") ///
                legend(off)

            graph export "`OUTDIR'/Fig_DL_`x'_`y'.png", replace
        }
    }
restore

****************************************************
* 7B) Cumulative path figures
****************************************************
preserve
    import delimited using "`OUTDIR'/Step2_5_CumPath.csv", clear

    gen ub = cum + 1.96*cum_se
    gen lb = cum - 1.96*cum_se

    levelsof intensity, local(ints2)
    foreach x of local ints2 {
        levelsof outcome if intensity=="`x'", local(outs2)
        foreach y of local outs2 {

            twoway ///
                (rcap ub lb h if intensity=="`x'" & outcome=="`y'") ///
                (connected cum h if intensity=="`x'" & outcome=="`y'"), ///
                yline(0) ///
                xtitle("Horizon h (quarters), cumulative 0..h") ///
                ytitle("Cumulative effect") ///
                title("Cumulative path: `y' on `x'") ///
                legend(off)

            graph export "`OUTDIR'/Fig_CUM_`x'_`y'.png", replace
        }
    }
restore

di as text "DONE: figures saved as PNGs."

****************************************************
* 8) JOURNAL-STYLE EXPORT TABLES (2 PANELS)
*    TEX + RTF
****************************************************

local outcomes "dv_rate_nettotal_w dv_rate_netperm_w dv_rate_inperm_w dv_rate_outperm_w"
local leadq 4
local mtitles_y `" "Net total" "Net permanent" "In permanent" "Out permanent" "'

local ZIPFE   "Yes"
local QTRFE   "Yes"
local CLUSSE  "ZIP"

****************************************************
* 8.0b) SCALE raw intensity
****************************************************
cap drop wf_zip_1e6
gen double wf_zip_1e6 = wf_zip * 1000000
label var wf_zip_1e6 "Raw wildfire intensity (t) × 1e6"

****************************************************
* 8.1) STORE MODELS
****************************************************
eststo clear
local j = 0

foreach y of local outcomes {
    local ++j

    quietly xtreg `y' ///
        ln_wf_zip L.ln_wf_zip L2.ln_wf_zip L3.ln_wf_zip L4.ln_wf_zip ///
        L5.ln_wf_zip L6.ln_wf_zip L7.ln_wf_zip L8.ln_wf_zip ///
        F`leadq'.ln_wf_zip ///
        i.yq, fe vce(cluster zip)

    estadd scalar r2_within = e(r2_within)

    quietly lincom ln_wf_zip + L.ln_wf_zip + L2.ln_wf_zip + L3.ln_wf_zip + L4.ln_wf_zip
    estadd scalar cum04   = r(estimate)
    estadd scalar cum04_p = r(p)

    quietly lincom ln_wf_zip + L.ln_wf_zip + L2.ln_wf_zip + L3.ln_wf_zip + L4.ln_wf_zip ///
                   + L5.ln_wf_zip + L6.ln_wf_zip + L7.ln_wf_zip + L8.ln_wf_zip
    estadd scalar cum08   = r(estimate)
    estadd scalar cum08_p = r(p)

    cap test F`leadq'.ln_wf_zip
    if _rc==0 estadd scalar lead_p = r(p)
    if _rc!=0 estadd scalar lead_p = .

    estadd local zip_fe  "`ZIPFE'"
    estadd local qtr_fe  "`QTRFE'"
    estadd local clus_se "`CLUSSE'"

    eststo ln`j'

    quietly xtreg `y' ///
        wf_zip_1e6 L.wf_zip_1e6 L2.wf_zip_1e6 L3.wf_zip_1e6 L4.wf_zip_1e6 ///
        L5.wf_zip_1e6 L6.wf_zip_1e6 L7.wf_zip_1e6 L8.wf_zip_1e6 ///
        F`leadq'.wf_zip_1e6 ///
        i.yq, fe vce(cluster zip)

    estadd scalar r2_within = e(r2_within)

    quietly lincom wf_zip_1e6 + L.wf_zip_1e6 + L2.wf_zip_1e6 + L3.wf_zip_1e6 + L4.wf_zip_1e6
    estadd scalar cum04   = r(estimate)
    estadd scalar cum04_p = r(p)

    quietly lincom wf_zip_1e6 + L.wf_zip_1e6 + L2.wf_zip_1e6 + L3.wf_zip_1e6 + L4.wf_zip_1e6 ///
                   + L5.wf_zip_1e6 + L6.wf_zip_1e6 + L7.wf_zip_1e6 + L8.wf_zip_1e6
    estadd scalar cum08   = r(estimate)
    estadd scalar cum08_p = r(p)

    cap test F`leadq'.wf_zip_1e6
    if _rc==0 estadd scalar lead_p = r(p)
    if _rc!=0 estadd scalar lead_p = .

    estadd local zip_fe  "`ZIPFE'"
    estadd local qtr_fe  "`QTRFE'"
    estadd local clus_se "`CLUSSE'"

    eststo raw`j'
}

****************************************************
* 8.2) MODEL LISTS
****************************************************
local M_LN  "ln1 ln2 ln3 ln4"
local M_RAW "raw1 raw2 raw3 raw4"

****************************************************
* 8.3) LABELS
****************************************************
local LAB_LN ///
    coeflabels( ///
      ln_wf_zip         "Log intensity (t)" ///
      L.ln_wf_zip       "Lag 1" ///
      L2.ln_wf_zip      "Lag 2" ///
      L3.ln_wf_zip      "Lag 3" ///
      L4.ln_wf_zip      "Lag 4" ///
      L5.ln_wf_zip      "Lag 5" ///
      L6.ln_wf_zip      "Lag 6" ///
      L7.ln_wf_zip      "Lag 7" ///
      L8.ln_wf_zip      "Lag 8" ///
      F`leadq'.ln_wf_zip "Lead 4" ///
    )

local LAB_RAW ///
    coeflabels( ///
      wf_zip_1e6          "Raw intensity (t) × 1e6" ///
      L.wf_zip_1e6        "Lag 1" ///
      L2.wf_zip_1e6       "Lag 2" ///
      L3.wf_zip_1e6       "Lag 3" ///
      L4.wf_zip_1e6       "Lag 4" ///
      L5.wf_zip_1e6       "Lag 5" ///
      L6.wf_zip_1e6       "Lag 6" ///
      L7.wf_zip_1e6       "Lag 7" ///
      L8.wf_zip_1e6       "Lag 8" ///
      F`leadq'.wf_zip_1e6 "Lead 4" ///
    )

****************************************************
* 8.4) EXPORT PANEL A: ln_wf_zip (RTF + TEX)
****************************************************
esttab `M_LN' using "`OUTDIR'/T8A_DL_LogIntensity_FullSample.rtf", replace rtf ///
    keep(*ln_wf_zip*) ///
    order(ln_wf_zip L.ln_wf_zip L2.ln_wf_zip L3.ln_wf_zip L4.ln_wf_zip L5.ln_wf_zip L6.ln_wf_zip L7.ln_wf_zip L8.ln_wf_zip F`leadq'.ln_wf_zip) ///
    `LAB_LN' ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles_y') ///
    stats(N r2_within cum04 cum04_p cum08 cum08_p lead_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" ///
                 "Cum 0–4" "Cum 0–4 p" ///
                 "Cum 0–8" "Cum 0–8 p" ///
                 "Lead p-value" "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 6 3 6 3 3 0 0 0)) ///
    title("Distributed Lag + Cumulative + Lead (Full Sample) — Panel A: Log wildfire intensity") ///
    nonotes

esttab `M_LN' using "`OUTDIR'/T8A_DL_LogIntensity_FullSample.tex", replace booktabs ///
    keep(*ln_wf_zip*) ///
    order(ln_wf_zip L.ln_wf_zip L2.ln_wf_zip L3.ln_wf_zip L4.ln_wf_zip L5.ln_wf_zip L6.ln_wf_zip L7.ln_wf_zip L8.ln_wf_zip F`leadq'.ln_wf_zip) ///
    `LAB_LN' ///
    b(%9.6f) se(%9.6f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles_y') ///
    stats(N r2_within cum04 cum04_p cum08 cum08_p lead_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" ///
                 "Cum 0–4" "Cum 0–4 p" ///
                 "Cum 0–8" "Cum 0–8 p" ///
                 "Lead p-value" "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 6 3 6 3 3 0 0 0)) ///
    title("Distributed Lag + Cumulative + Lead (Full Sample) — Panel A: Log wildfire intensity") ///
    nonotes

****************************************************
* 8.5) EXPORT PANEL B: wf_zip × 1e6 (RTF + TEX)
****************************************************
esttab `M_RAW' using "`OUTDIR'/T8B_DL_RawIntensity_x1e6_FullSample.rtf", replace rtf ///
    keep(*wf_zip_1e6*) ///
    order(wf_zip_1e6 L.wf_zip_1e6 L2.wf_zip_1e6 L3.wf_zip_1e6 L4.wf_zip_1e6 L5.wf_zip_1e6 L6.wf_zip_1e6 L7.wf_zip_1e6 L8.wf_zip_1e6 F`leadq'.wf_zip_1e6) ///
    `LAB_RAW' ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles_y') ///
    stats(N r2_within cum04 cum04_p cum08 cum08_p lead_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" ///
                 "Cum 0–4 (×1e6)" "Cum 0–4 p" ///
                 "Cum 0–8 (×1e6)" "Cum 0–8 p" ///
                 "Lead p-value" "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 3 3 3 3 0 0 0)) ///
    title("Distributed Lag + Cumulative + Lead (Full Sample) — Panel B: Raw wildfire intensity (× 1e6)") ///
    nonotes

esttab `M_RAW' using "`OUTDIR'/T8B_DL_RawIntensity_x1e6_FullSample.tex", replace booktabs ///
    keep(*wf_zip_1e6*) ///
    order(wf_zip_1e6 L.wf_zip_1e6 L2.wf_zip_1e6 L3.wf_zip_1e6 L4.wf_zip_1e6 L5.wf_zip_1e6 L6.wf_zip_1e6 L7.wf_zip_1e6 L8.wf_zip_1e6 F`leadq'.wf_zip_1e6) ///
    `LAB_RAW' ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles(`mtitles_y') ///
    stats(N r2_within cum04 cum04_p cum08 cum08_p lead_p zip_fe qtr_fe clus_se, ///
          labels("Observations" "Within R-squared" ///
                 "Cum 0–4 (×1e6)" "Cum 0–4 p" ///
                 "Cum 0–8 (×1e6)" "Cum 0–8 p" ///
                 "Lead p-value" "ZIP FE" "Quarter FE" "Clustered SE") ///
          fmt(0 3 3 3 3 3 3 0 0 0)) ///
    title("Distributed Lag + Cumulative + Lead (Full Sample) — Panel B: Raw wildfire intensity (× 1e6)") ///
    nonotes

di as text "DONE: Exported all CSV, PNG, RTF, and TEX files to `OUTDIR'"
