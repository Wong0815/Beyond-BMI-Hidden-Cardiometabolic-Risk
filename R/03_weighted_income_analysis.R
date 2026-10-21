# ============================================================
# 03 - WEIGHTED INCOME ANALYSIS
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
# PREPARE INCOME ANALYSIS DATA
# ------------------------------------------------------------

income_model_data <- current_complete %>%
  filter(
    !is.na(income_group),
    !is.na(ridageyr),
    !is.na(sex),
    !is.na(bmi),
    !is.na(hidden_risk),
    !is.na(wtsaf2yr)
  ) %>%
  mutate(
    
    # Highest-income group is the reference group
    income_group = factor(
      income_group,
      levels = c(
        "4.00+ PIR",
        "2.00-3.99 PIR",
        "1.00-1.99 PIR",
        "Below Poverty"
      ),
      labels = c(
        "400%+ of Poverty Level",
        "200-399% of Poverty Level",
        "100-199% of Poverty Level",
        "Below Poverty"
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

income_design <- create_design(
  income_model_data,
  start_yr = 2021,
  end_yr = 2021,
  wt_type = "fasting"
)


# ------------------------------------------------------------
# WEIGHTED HIDDEN-RISK PREVALENCE BY INCOME
# ------------------------------------------------------------

weighted_income_prevalence <- svyby(
  ~hidden_risk,
  ~income_group,
  income_design,
  svymean,
  vartype = "ci",
  na.rm = TRUE
) %>%
  as.data.frame()


# ------------------------------------------------------------
# RENAME PREVALENCE COLUMNS
# ------------------------------------------------------------

names(weighted_income_prevalence)[
  names(weighted_income_prevalence) == "hidden_risk"
] <- "Hidden_Risk_Prevalence"

names(weighted_income_prevalence)[
  names(weighted_income_prevalence) == "ci_l"
] <- "Hidden_Risk_Prevalence_low"

names(weighted_income_prevalence)[
  names(weighted_income_prevalence) == "ci_u"
] <- "Hidden_Risk_Prevalence_upp"


print(weighted_income_prevalence)


# ------------------------------------------------------------
# SAVE WEIGHTED PREVALENCE
# ------------------------------------------------------------

write_csv(
  weighted_income_prevalence,
  "results/weighted_income_prevalence.csv"
)


# ============================================================
# WEIGHTED LOGISTIC REGRESSION
# Adjusted for age, sex, and BMI
# ============================================================

weighted_income_model <- svyglm(
  hidden_risk ~
    income_group +
    ridageyr +
    sex +
    bmi,
  design = income_design,
  family = quasibinomial()
)


summary(weighted_income_model)


# ------------------------------------------------------------
# CONVERT REGRESSION RESULTS TO ODDS RATIOS
# ------------------------------------------------------------

weighted_income_OR <- tidy(
  weighted_income_model,
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


print(weighted_income_OR)


# ------------------------------------------------------------
# SAVE WEIGHTED ODDS RATIOS
# ------------------------------------------------------------

write_csv(
  weighted_income_OR,
  "results/weighted_income_odds_ratios.csv"
)


# ============================================================
# VALIDATION
# ============================================================

cat("\n---------------------------------------------\n")
cat("WEIGHTED INCOME ANALYSIS VALIDATION\n")
cat("---------------------------------------------\n")

cat(
  "Income analysis sample:",
  nrow(income_model_data),
  "\n\n"
)

cat("Weighted prevalence by income:\n")
print(weighted_income_prevalence)

cat("\nAdjusted odds ratios:\n")
print(weighted_income_OR)