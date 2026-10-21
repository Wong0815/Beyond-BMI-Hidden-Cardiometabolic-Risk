# ============================================================
# 04 - WEIGHTED RACE / ETHNICITY ANALYSIS
# Beyond BMI: Hidden Cardiometabolic Risk
# ============================================================

library(nhanesdata)
library(dplyr)
library(survey)
library(broom)
library(readr)


# ------------------------------------------------------------
# LOAD DATA PREPARATION
# ------------------------------------------------------------

source("R/01_data_preparation.R")


# ------------------------------------------------------------
# PREPARE RACE / ETHNICITY ANALYSIS DATA
# ------------------------------------------------------------

race_model_data <- current_complete %>%
  filter(
    !is.na(race_ethnicity),
    !is.na(ridageyr),
    !is.na(sex),
    !is.na(bmi),
    !is.na(hidden_risk),
    !is.na(wtsaf2yr)
  ) %>%
  mutate(
    
    # Non-Hispanic White is the regression reference group
    race_ethnicity = factor(
      race_ethnicity,
      levels = c(
        "Non-Hispanic White",
        "Mexican American",
        "Other Hispanic",
        "Non-Hispanic Black",
        "Non-Hispanic Asian",
        "Other Race - Including Multi-Racial"
      )
    ),
    
    sex = factor(
      sex,
      levels = c(
        "Female",
        "Male"
      )
    )
  )


# ------------------------------------------------------------
# CREATE NHANES SURVEY DESIGN
#
# Fasting weights are used because triglycerides are part
# of the hidden cardiometabolic risk definition.
# ------------------------------------------------------------

race_design <- create_design(
  race_model_data,
  start_yr = 2021,
  end_yr = 2021,
  wt_type = "fasting"
)


# ------------------------------------------------------------
# WEIGHTED HIDDEN-RISK PREVALENCE BY RACE / ETHNICITY
# ------------------------------------------------------------

weighted_risk_by_race <- svyby(
  ~hidden_risk,
  ~race_ethnicity,
  race_design,
  svymean,
  vartype = "ci",
  na.rm = TRUE
) %>%
  as.data.frame()


# ------------------------------------------------------------
# RENAME PREVALENCE COLUMNS
# ------------------------------------------------------------

names(weighted_risk_by_race)[
  names(weighted_risk_by_race) == "hidden_risk"
] <- "Hidden_Risk_Prevalence"

names(weighted_risk_by_race)[
  names(weighted_risk_by_race) == "ci_l"
] <- "Hidden_Risk_Prevalence_low"

names(weighted_risk_by_race)[
  names(weighted_risk_by_race) == "ci_u"
] <- "Hidden_Risk_Prevalence_upp"


print(weighted_risk_by_race)


# ------------------------------------------------------------
# SAVE WEIGHTED PREVALENCE RESULTS
# ------------------------------------------------------------

write_csv(
  weighted_risk_by_race,
  "results/weighted_risk_by_race.csv"
)


# ============================================================
# WEIGHTED LOGISTIC REGRESSION
# Adjusted for age, sex, and BMI
# ============================================================

weighted_race_model <- svyglm(
  hidden_risk ~
    race_ethnicity +
    ridageyr +
    sex +
    bmi,
  design = race_design,
  family = quasibinomial()
)


summary(weighted_race_model)


# ------------------------------------------------------------
# CONVERT REGRESSION RESULTS TO ODDS RATIOS
# ------------------------------------------------------------

weighted_race_OR <- tidy(
  weighted_race_model,
  conf.int = TRUE
) %>%
  mutate(
    Odds_Ratio = exp(estimate),
    CI_Lower = exp(conf.low),
    CI_Upper = exp(conf.high),
    P_Value = p.value
  ) %>%
  select(
    term,
    Odds_Ratio,
    CI_Lower,
    CI_Upper,
    P_Value
  ) %>%
  mutate(
    Odds_Ratio = round(Odds_Ratio, 2),
    CI_Lower = round(CI_Lower, 2),
    CI_Upper = round(CI_Upper, 2),
    P_Value = round(P_Value, 4)
  )


print(weighted_race_OR)


# ------------------------------------------------------------
# SAVE WEIGHTED ODDS RATIOS
# ------------------------------------------------------------

write_csv(
  weighted_race_OR,
  "results/weighted_race_odds_ratios.csv"
)


# ============================================================
# VALIDATION
# ============================================================

cat("\n---------------------------------------------\n")
cat("WEIGHTED RACE / ETHNICITY ANALYSIS VALIDATION\n")
cat("---------------------------------------------\n")

cat(
  "Race analysis sample:",
  nrow(race_model_data),
  "\n\n"
)

cat("Weighted prevalence by race / ethnicity:\n")
print(weighted_risk_by_race)

cat("\nAdjusted odds ratios:\n")
print(weighted_race_OR)