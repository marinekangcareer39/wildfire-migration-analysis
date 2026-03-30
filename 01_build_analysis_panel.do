****************************************************
* Final DATA Cleaning - Merge_Marine (STABILIZED v2)
* NEW USPS DV + POP INCLUDED + FIXED Method2 (positive thresholds)
* Output: FINAL_REGRESSION_TWFE_CA_2017q2_2023q1.dta
* Window: 2017q2–2023q1 (24 quarters)
* Keeps: DV-observed quarters only (dv_matched==1)
* Does NOT force balanced panel
*
* DV from USPS:
*   dv_net_perm        = net_perm (perm in - perm out)
*   dv_inperm          = movein_perm (perm in only)
*
* Per-capita migration rates:
*   dv_rate_netperm    = net_perm / pop
*   dv_rate_nettotal   = net_total / pop
*   dv_rate_inperm     = movein_perm / pop
*   dv_rate_outperm    = moveout_perm / pop
*
* Wildfire Method 1 (broad exposure):
*   wf_exposure            = event in quarter (0/1)
*   wf_first_fire_yq       = first quarter with wf_exposure==1 (within FINAL DV sample)
*   wf_exposure_ever       = absorbing: 1 if yq >= wf_first_fire_yq
*
* Wildfire Method 2 (FIXED): thresholds computed among POSITIVE wf_zip only
*   wf_pos_event           = 1 if wf_zip>0
*   wf_pos_first_yq        = first yq with wf_zip>0 (within FINAL DV sample)
*   wf_pos_ever            = absorbing from first positive intensity
*
*   wf_int50p_event        = 1 if wf_zip >= p50 of wf_zip | wf_zip>0  (else 0)
*   wf_int75p_event        = 1 if wf_zip >= p75 of wf_zip | wf_zip>0  (else 0)
*   wf_int90p_event        = 1 if wf_zip >= p90 of wf_zip | wf_zip>0  (else 0)
*   wf_int*_first_yq       = first exceedance quarter (within FINAL DV sample)
*   wf_int*_ever           = absorbing from first exceedance
*
* QC / diagnostics:
*   wf_toggle_zip      = ZIP has 1->0 toggles in raw wf_exposure over observed quarters
*   sample_no_toggle   = 1 if wf_toggle_zip==0
*   house_merge        = merge flag for housing
*   house_miss         = 1 if median_house_price missing
*   share_house_miss   = ZIP-level share of missing housing
*
*   pop_small          = 1 if pop < p1 (within DV sample)
*   dv_rate_*_flag     = 1 if |rate|>1 (outlier diagnostic only)
*   optional winsor flags included (does NOT overwrite rates)
****************************************************

clear all
set more off
browse

****************************************************
* 0) PATHS
****************************************************
local popincome "/Users/marine/Documents/Senior IS/Economics/Senior IS Data/Data Cleaning/popincome_zip_quarter_CA.dta"
local wildfire  "/Users/marine/Documents/Senior IS/Economics/Senior IS Data/Data Cleaning/wildfire_zip_quarter_CA_2017q2_2023q1_exposure_intensity.dta"
local housing   "/Users/marine/Documents/Senior IS/Economics/Senior IS Data/Data Cleaning/housing_zip_quarter_CA.dta"
local uspsdv    "/Users/marine/Documents/Senior IS/Economics/Senior IS Data/Data Cleaning/DV. USPS/usps_quarterly_CA_2017q2_2023q1.dta"
local out_final "/Users/marine/Documents/Senior IS/Economics/Senior IS Data/Data Cleaning/FINAL_REGRESSION_TWFE_CA_2017q2_2023q1.dta"

****************************************************
* 0.1) WINDOW
****************************************************
local yq_min = yq(2017,2)
local yq_max = yq(2023,1)

****************************************************
* 1) WILDFIRE clean (zip,yq)
****************************************************
clear
use "`wildfire'", clear

capture confirm numeric variable zip
if _rc destring zip, replace force
recast int yq
format yq %tq

keep if inrange(zip, 90001, 96199)
keep if inrange(yq, `yq_min', `yq_max')

keep zip yq wf_exposure wf_zip
isid zip yq

tempfile wf_clean
save `wf_clean', replace


****************************************************
* 2) HOUSING clean (zip,yq)
****************************************************
clear
use "`housing'", clear

capture confirm numeric variable zip
if _rc destring zip, replace force
recast int yq
format yq %tq

keep if inrange(zip, 90001, 96199)
keep if inrange(yq, `yq_min', `yq_max')

capture confirm variable median_house_price
if _rc {
    capture confirm variable median_sale_price
    if !_rc rename median_sale_price median_house_price
}

keep zip yq median_house_price
isid zip yq

tempfile house_clean
save `house_clean', replace


****************************************************
* 3) USPS DV clean (zip,yq)
****************************************************
clear
use "`uspsdv'", clear

capture confirm numeric variable zip
if _rc destring zip, replace force
recast int yq
format yq %tq

keep if inrange(zip, 90001, 96199)
keep if inrange(yq, `yq_min', `yq_max')

keep zip yq ///
     movein_total moveout_total net_total ///
     movein_perm  moveout_perm  net_perm

* Duplicates check (should be none, but robust)
capture drop dup
duplicates tag zip yq, gen(dup)
count if dup>0
if r(N)>0 {
    collapse (sum) movein_total moveout_total net_total ///
                  movein_perm moveout_perm net_perm, by(zip yq)
}
drop dup
isid zip yq

label var movein_total  "USPS COA total move-ins (quarterly sum)"
label var moveout_total "USPS COA total move-outs (quarterly sum)"
label var net_total     "USPS COA net total (in - out), quarterly"
label var movein_perm   "USPS COA permanent move-ins (quarterly sum)"
label var moveout_perm  "USPS COA permanent move-outs (quarterly sum)"
label var net_perm      "USPS COA net permanent (in - out), quarterly"

tempfile usps_clean
save `usps_clean', replace


****************************************************
* 4) Load POPINCOME master (zip,yq)
****************************************************
clear
use "`popincome'", clear

capture confirm numeric variable zip
if _rc destring zip, replace force
recast int yq
format yq %tq

keep if inrange(zip, 90001, 96199)
keep if inrange(yq, `yq_min', `yq_max')
isid zip yq

* Ensure year/quarter exist
capture confirm variable year
if _rc gen year = yofd(dofq(yq))

capture confirm variable quarter
if _rc gen str7 quarter = string(year) + "q" + string(quarter(dofq(yq)))


****************************************************
* 4.5) DIAGNOSTIC: track using-only drops later
****************************************************
tempvar keep_master
gen byte `keep_master' = 1


****************************************************
* 5) Merge WILDFIRE (missing -> 0)
****************************************************
merge 1:1 zip yq using `wf_clean'
gen byte wf_merge = _merge
drop if _merge==2

replace wf_exposure = 0 if _merge==1 & missing(wf_exposure)
replace wf_zip      = 0 if _merge==1 & missing(wf_zip)
drop _merge

label var wf_exposure "Wildfire event (broad) (ZIP-quarter)"
label var wf_zip      "Wildfire intensity proxy (acres-weighted)"
label var wf_merge    "WF merge flag (1=master only; 3=matched)"


****************************************************
* 6) Merge HOUSING (keep merge flag)
****************************************************
merge 1:1 zip yq using `house_clean', gen(house_merge)
drop if house_merge==2

label define housem 1 "master only (no housing)" 3 "matched"
label values house_merge housem
label var house_merge "Housing merge flag (1=missing in housing; 3=matched)"


****************************************************
* 7) Baseline transforms (do NOT drop missings)
****************************************************
capture drop ln_median_income ln_house_price ln_wf_zip ///
            dv_net_perm dv_inperm ///
            dv_rate_netperm dv_rate_nettotal dv_rate_inperm dv_rate_outperm ///
            dv_matched ///
            wf_first_fire_yq wf_exposure_ever ///
            wf_zip_cum ln_wf_zip_cum ///
            wf_toggle_zip sample_no_toggle ///
            house_miss share_house_miss ///
            zip_ever_treated house_none_zip ///
            wf_pos_event wf_pos_first_yq wf_pos_ever ///
            wf_int50p_event wf_int75p_event wf_int90p_event ///
            wf_int50p_first_yq wf_int75p_first_yq wf_int90p_first_yq ///
            wf_int50p_ever wf_int75p_ever wf_int90p_ever ///
            pop_small ///
            dv_rate_netperm_flag dv_rate_nettotal_flag dv_rate_inperm_flag dv_rate_outperm_flag ///
            dv_rate_netperm_w dv_rate_nettotal_w dv_rate_inperm_w dv_rate_outperm_w

gen ln_median_income = ln(median_income) if median_income>0
gen ln_house_price   = ln(median_house_price) if median_house_price>0
gen ln_wf_zip        = ln(wf_zip + 1) if wf_zip>=0

* placeholders (filled after DV merge)
gen dv_net_perm       = .
gen dv_inperm         = .
gen dv_rate_netperm   = .
gen dv_rate_nettotal  = .
gen dv_rate_inperm    = .
gen dv_rate_outperm   = .


****************************************************
* 8) Merge USPS DV + keep DV-observed quarters only
****************************************************
merge 1:1 zip yq using `usps_clean'
gen byte usps_merge = _merge
drop if _merge==2

gen byte dv_matched = (usps_merge==3)
label var dv_matched "1 if USPS DV exists (matched)"
label var usps_merge "USPS merge flag (1=master only; 3=matched)"

replace dv_net_perm = net_perm if dv_matched==1
label var dv_net_perm "DV: net permanent migration (in - out), quarterly"

replace dv_inperm   = movein_perm if dv_matched==1
label var dv_inperm "DV: permanent move-ins, quarterly"

replace dv_rate_netperm  = net_perm     / pop if dv_matched==1 & pop>0
replace dv_rate_nettotal = net_total    / pop if dv_matched==1 & pop>0
replace dv_rate_inperm   = movein_perm  / pop if dv_matched==1 & pop>0
replace dv_rate_outperm  = moveout_perm / pop if dv_matched==1 & pop>0

label var dv_rate_netperm  "DV: net_perm / pop"
label var dv_rate_nettotal "DV: net_total / pop"
label var dv_rate_inperm   "DV: movein_perm / pop"
label var dv_rate_outperm  "DV: moveout_perm / pop"

drop _merge

* Keep only quarters where DV exists
keep if dv_matched==1


****************************************************
* 8.3) Per-capita outlier diagnostics (DO NOT DROP automatically)
****************************************************
* pop small flag (within DV sample)
summ pop, detail
local pop_p1 = r(p1)
gen byte pop_small = (pop>0 & pop < `pop_p1')
label var pop_small "QC: pop below p1 (within DV sample)"

* rate outlier flags: |rate|>1 (adjust threshold if you want)
gen byte dv_rate_netperm_flag  = (abs(dv_rate_netperm)  > 1) if !missing(dv_rate_netperm)
gen byte dv_rate_nettotal_flag = (abs(dv_rate_nettotal) > 1) if !missing(dv_rate_nettotal)
gen byte dv_rate_inperm_flag   = (abs(dv_rate_inperm)   > 1) if !missing(dv_rate_inperm)
gen byte dv_rate_outperm_flag  = (abs(dv_rate_outperm)  > 1) if !missing(dv_rate_outperm)

label var dv_rate_netperm_flag  "QC: |dv_rate_netperm|>1"
label var dv_rate_nettotal_flag "QC: |dv_rate_nettotal|>1"
label var dv_rate_inperm_flag   "QC: |dv_rate_inperm|>1"
label var dv_rate_outperm_flag  "QC: |dv_rate_outperm|>1"

* OPTIONAL winsorized copies at 1/99 (do not overwrite originals)
foreach v in dv_rate_netperm dv_rate_nettotal dv_rate_inperm dv_rate_outperm {
    summarize `v', detail
    local lo = r(p1)
    local hi = r(p99)
    gen double `v'_w = `v'
    replace `v'_w = `lo' if `v'_w < `lo' & !missing(`v'_w)
    replace `v'_w = `hi' if `v'_w > `hi' & !missing(`v'_w)
    label var `v'_w "Winsorized `v' (p1/p99 within DV sample)"
}


****************************************************
* 8.5) Method 1: Broad exposure absorbing treatment
****************************************************
sort zip yq

bys zip: egen wf_first_fire_yq = min(cond(wf_exposure==1, yq, .))
format wf_first_fire_yq %tq
label var wf_first_fire_yq "M1: First wildfire quarter (broad exposure, within DV sample)"

gen byte wf_exposure_ever = (!missing(wf_first_fire_yq) & yq >= wf_first_fire_yq)
label var wf_exposure_ever "M1: Treated status (absorbing) from first broad exposure"

* cumulative intensity (within DV sample)
bys zip (yq): gen double wf_zip_cum = sum(wf_zip)
label var wf_zip_cum "Cumulative wildfire intensity (within DV sample)"

gen ln_wf_zip_cum = ln(wf_zip_cum + 1) if wf_zip_cum>=0
label var ln_wf_zip_cum "ln(cumulative wf_zip + 1)"

* Toggle diagnostic on raw broad exposure event (1->0)
by zip: gen byte _drop10 = (wf_exposure < wf_exposure[_n-1]) if _n>1
bys zip: egen byte wf_toggle_zip = max(_drop10)
drop _drop10
label var wf_toggle_zip "QC: ZIP has 1->0 toggles in wf_exposure (broad)"

gen byte sample_no_toggle = (wf_toggle_zip==0)
label var sample_no_toggle "QC: sample flag 1 if no toggles (broad)"


****************************************************
* 8.55) Optional robustness flag: early-treated in first sample quarter
****************************************************
gen byte wf_first_is_2017q2 = (wf_first_fire_yq==`yq_min')
label var wf_first_is_2017q2 "QC/Robustness: M1 first_fire == 2017q2"


****************************************************
* 8.6) Method 2 FIXED: compute thresholds among POSITIVE wf_zip only
****************************************************
* Basic positive-intensity treatment (any >0)
gen byte wf_pos_event = (wf_zip>0)
bys zip: egen wf_pos_first_yq = min(cond(wf_pos_event==1, yq, .))
format wf_pos_first_yq %tq
gen byte wf_pos_ever = (!missing(wf_pos_first_yq) & yq >= wf_pos_first_yq)

label var wf_pos_event    "M2(base): wf_zip>0 event"
label var wf_pos_first_yq "M2(base): first yq wf_zip>0 (within DV sample)"
label var wf_pos_ever     "M2(base): absorbing from first wf_zip>0"

* thresholds among positive wf_zip ONLY
summ wf_zip if wf_zip>0, detail
local th50p = r(p50)
local th75p = r(p75)
local th90p = r(p90)

display as text "M2 positive thresholds (wf_zip | wf_zip>0): p50=" `th50p' " p75=" `th75p' " p90=" `th90p'

* quarter-level exceedance events (set 0 when wf_zip==0)
gen byte wf_int50p_event = (wf_zip >= `th50p') if wf_zip>0
replace wf_int50p_event = 0 if wf_zip==0
gen byte wf_int75p_event = (wf_zip >= `th75p') if wf_zip>0
replace wf_int75p_event = 0 if wf_zip==0
gen byte wf_int90p_event = (wf_zip >= `th90p') if wf_zip>0
replace wf_int90p_event = 0 if wf_zip==0

label var wf_int50p_event "M2: event wf_zip>=p50 among positives"
label var wf_int75p_event "M2: event wf_zip>=p75 among positives"
label var wf_int90p_event "M2: event wf_zip>=p90 among positives"

* first exceedance quarter (within DV sample)
bys zip: egen wf_int50p_first_yq = min(cond(wf_int50p_event==1, yq, .))
bys zip: egen wf_int75p_first_yq = min(cond(wf_int75p_event==1, yq, .))
bys zip: egen wf_int90p_first_yq = min(cond(wf_int90p_event==1, yq, .))

format wf_int50p_first_yq wf_int75p_first_yq wf_int90p_first_yq %tq
label var wf_int50p_first_yq "M2: first yq >= p50(positive wf_zip)"
label var wf_int75p_first_yq "M2: first yq >= p75(positive wf_zip)"
label var wf_int90p_first_yq "M2: first yq >= p90(positive wf_zip)"

* absorbing from first exceedance
gen byte wf_int50p_ever = (!missing(wf_int50p_first_yq) & yq >= wf_int50p_first_yq)
gen byte wf_int75p_ever = (!missing(wf_int75p_first_yq) & yq >= wf_int75p_first_yq)
gen byte wf_int90p_ever = (!missing(wf_int90p_first_yq) & yq >= wf_int90p_first_yq)

label var wf_int50p_ever "M2 treated(absorbing): >=p50 among positives"
label var wf_int75p_ever "M2 treated(absorbing): >=p75 among positives"
label var wf_int90p_ever "M2 treated(absorbing): >=p90 among positives"


****************************************************
* 8.7) Housing diagnostics (post DV filter)
****************************************************
gen byte house_miss = missing(median_house_price)
bys zip: egen share_house_miss = mean(house_miss)
label var house_miss "1 if housing missing in this zip-yq"
label var share_house_miss "ZIP share of missing housing (0..1)"

* ZIP-level ever treated (M1) for correlation tables
bys zip: egen zip_ever_treated = max(wf_exposure_ever)
gen byte house_none_zip = (share_house_miss==1)
label var house_none_zip "1 if ZIP has no housing data in any observed quarter"


****************************************************
* 9) Keep regression vars (+ QC vars)
****************************************************
keep zip yq year quarter ///
     pop ///
     dv_net_perm dv_inperm ///
     dv_rate_netperm dv_rate_nettotal dv_rate_inperm dv_rate_outperm ///
     dv_rate_netperm_w dv_rate_nettotal_w dv_rate_inperm_w dv_rate_outperm_w ///
     movein_total moveout_total net_total ///
     movein_perm moveout_perm net_perm ///
     wf_exposure wf_first_fire_yq wf_exposure_ever ///
     wf_first_is_2017q2 ///
     wf_toggle_zip sample_no_toggle ///
     wf_zip ln_wf_zip wf_zip_cum ln_wf_zip_cum ///
     wf_pos_event wf_pos_first_yq wf_pos_ever ///
     wf_int50p_event wf_int50p_first_yq wf_int50p_ever ///
     wf_int75p_event wf_int75p_first_yq wf_int75p_ever ///
     wf_int90p_event wf_int90p_first_yq wf_int90p_ever ///
     median_income ln_median_income ///
     median_house_price ln_house_price ///
     wf_merge usps_merge house_merge ///
     house_miss share_house_miss ///
     zip_ever_treated house_none_zip ///
     pop_small ///
     dv_rate_netperm_flag dv_rate_nettotal_flag dv_rate_inperm_flag dv_rate_outperm_flag

order zip yq year quarter pop ///
      dv_net_perm dv_inperm ///
      dv_rate_netperm dv_rate_nettotal dv_rate_inperm dv_rate_outperm ///
      dv_rate_netperm_w dv_rate_nettotal_w dv_rate_inperm_w dv_rate_outperm_w ///
      wf_exposure wf_first_fire_yq wf_exposure_ever wf_first_is_2017q2 ///
      wf_pos_event wf_pos_first_yq wf_pos_ever ///
      wf_int50p_event wf_int50p_first_yq wf_int50p_ever ///
      wf_int75p_event wf_int75p_first_yq wf_int75p_ever ///
      wf_int90p_event wf_int90p_first_yq wf_int90p_ever ///
      wf_zip ln_wf_zip wf_zip_cum ln_wf_zip_cum ///
      median_income ln_median_income ///
      median_house_price ln_house_price ///
      wf_merge usps_merge house_merge ///
      house_miss share_house_miss ///
      wf_toggle_zip sample_no_toggle ///
      pop_small ///
      dv_rate_netperm_flag dv_rate_nettotal_flag dv_rate_inperm_flag dv_rate_outperm_flag ///
      zip_ever_treated house_none_zip


****************************************************
* 10) Panel declare + sort
****************************************************
xtset zip yq
sort zip yq


****************************************************
* 11) SANITY CHECKS (print diagnostics)
****************************************************
format yq %tq
isid zip yq

di as text "---- SANITY: yq coverage (must show 2017q2..2023q1) ----"
tab yq

di as text "---- SANITY: merge flags ----"
tab wf_merge
tab usps_merge
tab house_merge

di as text "---- SANITY: core missingness ----"
count if missing(pop)
count if pop==0
count if missing(ln_median_income)
count if missing(ln_house_price)

di as text "---- SANITY: Method 1 distributions ----"
tab wf_exposure, missing
tab wf_exposure_ever, missing
tab wf_first_fire_yq, missing
tab wf_first_is_2017q2

* Absorbing check (M1): ever should never go 1->0
by zip (yq): gen byte chk_m1_drop = (wf_exposure_ever==0 & wf_exposure_ever[_n-1]==1) if _n>1
count if chk_m1_drop==1
drop chk_m1_drop

* ZIP-level consistency (M1): any event == any ever
bys zip: egen chk_m1_any_event = max(wf_exposure)
bys zip: egen chk_m1_any_ever  = max(wf_exposure_ever)
assert chk_m1_any_event == chk_m1_any_ever
drop chk_m1_any_event chk_m1_any_ever

di as text "---- SANITY: Method 2 FIXED (positives) ----"
tab wf_pos_event
tab wf_pos_ever
tab wf_pos_first_yq, missing

tab wf_int50p_event
tab wf_int50p_ever
tab wf_int50p_first_yq, missing

tab wf_int75p_event
tab wf_int75p_ever
tab wf_int75p_first_yq, missing

tab wf_int90p_event
tab wf_int90p_ever
tab wf_int90p_first_yq, missing

* Absorbing checks (M2): 1->0 should not happen
by zip (yq): gen byte chk50p = (wf_int50p_ever==0 & wf_int50p_ever[_n-1]==1) if _n>1
by zip (yq): gen byte chk75p = (wf_int75p_ever==0 & wf_int75p_ever[_n-1]==1) if _n>1
by zip (yq): gen byte chk90p = (wf_int90p_ever==0 & wf_int90p_ever[_n-1]==1) if _n>1
count if chk50p==1
count if chk75p==1
count if chk90p==1
drop chk50p chk75p chk90p

* ZIP-level consistency (M2): any event == any ever
bys zip: egen chk50p_event = max(wf_int50p_event)
bys zip: egen chk50p_ever  = max(wf_int50p_ever)
assert chk50p_event == chk50p_ever
drop chk50p_event chk50p_ever

bys zip: egen chk75p_event = max(wf_int75p_event)
bys zip: egen chk75p_ever  = max(wf_int75p_ever)
assert chk75p_event == chk75p_ever
drop chk75p_event chk75p_ever

bys zip: egen chk90p_event = max(wf_int90p_event)
bys zip: egen chk90p_ever  = max(wf_int90p_ever)
assert chk90p_event == chk90p_ever
drop chk90p_event chk90p_ever

di as text "---- SANITY: rates / outliers ----"
summ pop, detail
summ dv_rate_netperm dv_rate_nettotal dv_rate_inperm dv_rate_outperm, detail
tab pop_small
tab dv_rate_netperm_flag
tab dv_rate_nettotal_flag
tab dv_rate_inperm_flag
tab dv_rate_outperm_flag

di as text "---- SANITY: housing diagnostics ----"
tab house_merge
tab house_miss
summ share_house_miss, detail
tab house_none_zip zip_ever_treated, row

di as text "---- SANITY: panel length ----"
bys zip: gen Ti=_N
summ Ti, detail
drop Ti

****************************************************
* 12) SAVE
****************************************************
save "`out_final'", replace
di as result "Saved FINAL: `out_final'"
