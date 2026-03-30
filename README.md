# Wildfire and Migration Analysis

This project examines the impact of wildfire exposure on migration patterns in California using ZIP code–level quarterly panel data (2017Q2–2023Q1).

## Data

The dataset integrates multiple sources, including:

* USPS migration data
* Wildfire exposure and intensity
* Housing data
* Population and income data

Due to data access and licensing restrictions, the raw dataset is not publicly available.
To run the code, place the required datasets in a `/data` folder.

## Code Structure

* `01_build_analysis_panel.do`: Constructs the final dataset
* `02_main_eventstudy.do`: Baseline event-study analysis
* `03_heterogeneity_income.do`: Income heterogeneity analysis
* `04_heterogeneity_house.do`: Housing heterogeneity analysis
* `05_distributed_lag.do`: Distributed lag analysis
* `06_post_dynamics.do`: Dynamic post-event effects
* `07_additional_regs.do`: Additional robustness checks

## Replication

To reproduce the results:

1. Place the required datasets in the `/data` folder
2. Update the project root path in each `.do` file
3. Run the scripts sequentially from `01` to `07`

All outputs will be saved in the `/output` directory.
