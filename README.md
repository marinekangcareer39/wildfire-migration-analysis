# Wildfire and Migration Analysis

This project analyzes the impact of wildfire exposure on migration patterns in California using ZIP code–level quarterly panel data (2017q2–2023q1).  Due to data access and licensing restrictions, the raw dataset is not publicly available.

## Data

The dataset combines:
- USPS migration data
- Wildfire exposure and intensity
- Housing data
- Population and income data

Raw data are not included due to size and access restrictions.  
To run the code, place datasets in a `/data` folder.

## Code Structure

- 01_build_analysis_panel.do: Construct final dataset
- 02_main_eventstudy.do: Baseline event-study
- 03_heterogeneity_income.do: Income heterogeneity
- 04_heterogeneity_house.do: Housing heterogeneity
- 05_distributed_lag.do: Distributed lag analysis
- 06_post_dynamics.do: Dynamic effects
- 07_additional_regs.do: Additional robustness checks

