## Reproducibility

This project was developed in RStudio using publicly available NHANES data. The analysis is organized into separate scripts for data preparation, statistical modeling, and visualization.

### Project Structure

```text
BMI_Project/
├── R/
│   ├── 01_data_preparation.R
│   ├── 02_mortality_analysis.R
│   ├── 03_weighted_income_analysis.R
│   ├── 04_weighted_race_analysis.R
│   ├── 05_weighted_education_analysis.R
│   └── 07_final_figures.R
├── data/
├── figures/
├── results/
├── BMI_Project.Rproj
└── README.md
```

### R Scripts

| Script | Description |
|---|---|
| `01_data_preparation.R` | Imports and cleans NHANES data, defines cardiometabolic risk factors, and prepares the analytical sample |
| `02_mortality_analysis.R` | Analyzes mortality outcomes using Cox proportional hazards regression |
| `03_weighted_income_analysis.R` | Estimates hidden risk prevalence and adjusted associations by income |
| `04_weighted_race_analysis.R` | Estimates hidden risk prevalence and adjusted associations by race/ethnicity |
| `05_weighted_education_analysis.R` | Estimates hidden risk prevalence and adjusted associations by education |
| `07_final_figures.R` | Generates the final project visualizations |

### How to Reproduce the Analysis

**1. Download the repository**

Clone or download this GitHub repository and open `BMI_Project.Rproj` in RStudio.

**2. Install the required R packages**

```r
install.packages(c(
  "nhanesdata",
  "dplyr",
  "survey",
  "survival",
  "broom",
  "ggplot2",
  "scales"
))
```

**3. Prepare the mortality data**

Download the 2019 Public-Use Linked Mortality Files for NHANES 2005–2018 from the [CDC Linked Mortality Files directory](https://ftp.cdc.gov/pub/health_statistics/NCHS/datalinkage/linked_mortality/).

Place the seven NHANES mortality `.dat` files in the `data/` folder.

These raw mortality files are not included in the GitHub repository.

**4. Run the analysis**

Run the scripts in the following order from the RStudio project directory:

```r
source("R/01_data_preparation.R")
source("R/02_mortality_analysis.R")
source("R/03_weighted_income_analysis.R")
source("R/04_weighted_race_analysis.R")
source("R/05_weighted_education_analysis.R")
source("R/07_final_figures.R")
```

**5. View the results**

The analysis generates:

- `results/` — Statistical summaries, prevalence estimates, odds ratios, and mortality model results
- `figures/` — Four visualizations showing overall hidden risk, individual risk factors, demographic differences, and mortality

The results and figures are included in the repository for reference.

### Data Availability

NHANES data are publicly available through the [CDC NHANES website](https://www.cdc.gov/nchs/nhanes/).

Historical mortality linkage files are available through the [CDC Linked Mortality Files directory](https://ftp.cdc.gov/pub/health_statistics/NCHS/datalinkage/linked_mortality/).
