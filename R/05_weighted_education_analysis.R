# ============================================================
# 05 - WEIGHTED EDUCATION ANALYSIS
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
# PREPARE EDUCATION ANALYSIS DATA
# ------------------------------------------------------------

education_model_data <- current_complete %>%
  filter(
    !is.na(education),
    !is.na(ridageyr),
    !is.na(sex),
    !is.na(bmi),
    !is.na(hidden_risk),
    !is.na(wtsaf2yr)
  ) %>%
  mutate(
    
    # College graduate or above is the reference group
    education = factor(
      education,
      levels = c(
        "College Graduate or Above",
        "Some College / AA",
        "High School / GED",
        "9th-11th Grade",
        "Less than 9th Grade"
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

education_design <- create_design(
  education_model_data,
  start_yr = 2021,
  end_yr = 2021,
  wt_type = "fasting"
)


# ------------------------------------------------------------
# WEIGHTED HIDDEN-RISK PREVALENCE BY EDUCATION
# ------------------------------------------------------------

weighted_risk_by_education <- svyby(
  ~hidden_risk,
  ~education,
  education_design,
  svymean,
  vartype = "ci",
  na.rm = TRUE
) %>%
  as.data.frame()


# ------------------------------------------------------------
# RENAME PREVALENCE COLUMNS
# ------------------------------------------------------------

names(weighted_risk_by_education)[
  names(weighted_risk_by_education) == "hidden_risk"
] <- "Hidden_Risk_Prevalence"

names(weighted_risk_by_education)[
  names(weighted_risk_by_education) == "ci_l"
] <- "Hidden_Risk_Prevalence_low"

names(weighted_risk_by_education)[
  names(weighted_risk_by_education) == "ci_u"
] <- "Hidden_Risk_Prevalence_upp"


print(weighted_risk_by_education)


# ------------------------------------------------------------
# SAVE WEIGHTED PREVALENCE RESULTS
# ------------------------------------------------------------

write_csv(
  weighted_risk_by_education,
  "results/weighted_risk_by_education.csv"
)


# ============================================================
# WEIGHTED LOGISTIC REGRESSION
# Adjusted for age, sex, and BMI
# ============================================================

weighted_education_model <- svyglm(
  hidden_risk ~
    education +
    ridageyr +
    sex +
    bmi,
  design = education_design,
  family = quasibinomial()
)


summary(weighted_education_model)


# ------------------------------------------------------------
# CONVERT REGRESSION RESULTS TO ODDS RATIOS
# ------------------------------------------------------------

weighted_education_OR <- tidy(
  weighted_education_model,
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


print(weighted_education_OR)


# ------------------------------------------------------------
# SAVE WEIGHTED ODDS RATIOS
# ------------------------------------------------------------

write_csv(
  weighted_education_OR,
  "results/weighted_education_odds_ratios.csv"
)


# ============================================================
# VALIDATION
# ============================================================

cat("\n---------------------------------------------\n")
cat("WEIGHTED EDUCATION ANALYSIS VALIDATION\n")
cat("---------------------------------------------\n")

cat(
  "Education analysis sample:",
  nrow(education_model_data),
  "\n\n"
)

cat("Weighted prevalence by education:\n")
print(weighted_risk_by_education)

cat("\nAdjusted odds ratios:\n")
print(weighted_education_OR)
