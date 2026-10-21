# ============================================================
# 01 - DATA PREPARATION
# Beyond BMI: Hidden Cardiometabolic Risk
# ============================================================

library(nhanesdata)
library(dplyr)


# ------------------------------------------------------------
# LOAD NHANES DATA
# ------------------------------------------------------------

demo_all <- read_nhanes("demo")
bmx_all  <- read_nhanes("bmx")
bpxo_all <- read_nhanes("bpxo")
a1c_all  <- read_nhanes("ghb")
hdl_all  <- read_nhanes("hdl")
trig_all <- read_nhanes("trigly")


# ------------------------------------------------------------
# KEEP 2021 CYCLE
# ------------------------------------------------------------

demo_current <- demo_all %>%
  filter(year == 2021)

bmx_current <- bmx_all %>%
  filter(year == 2021)

bpx_current <- bpxo_all %>%
  filter(year == 2021)

a1c_current <- a1c_all %>%
  filter(year == 2021)

hdl_current <- hdl_all %>%
  filter(year == 2021)

trig_current <- trig_all %>%
  filter(year == 2021)


# ------------------------------------------------------------
# CHECK DATA
# ------------------------------------------------------------

dim(demo_current)
dim(bmx_current)
dim(bpx_current)
dim(a1c_current)
dim(hdl_current)
dim(trig_current)


# ------------------------------------------------------------
# CLEAN ANALYSIS VARIABLES
# ------------------------------------------------------------

# BMI and waist circumference
bmx_current_clean <- bmx_current %>%
  select(
    seqn,
    year,
    bmi = bmxbmi,
    waist = bmxwaist
  )


# Blood pressure
# Average all available readings for each participant
bp_current_clean <- bpx_current %>%
  mutate(
    avg_sbp = rowMeans(
      across(c(bpxosy1, bpxosy2, bpxosy3)),
      na.rm = TRUE
    ),
    avg_dbp = rowMeans(
      across(c(bpxodi1, bpxodi2, bpxodi3)),
      na.rm = TRUE
    )
  ) %>%
  mutate(
    avg_sbp = ifelse(is.nan(avg_sbp), NA, avg_sbp),
    avg_dbp = ifelse(is.nan(avg_dbp), NA, avg_dbp)
  ) %>%
  select(
    seqn,
    year,
    avg_sbp,
    avg_dbp
  )


# A1C
a1c_current_clean <- a1c_current %>%
  select(
    seqn,
    year,
    a1c = lbxgh
  )


# HDL cholesterol
hdl_current_clean <- hdl_current %>%
  select(
    seqn,
    year,
    hdl = lbdhdd
  )


# Triglycerides and fasting survey weight
trig_current_clean <- trig_current %>%
  select(
    seqn,
    year,
    triglycerides = lbxtlg,
    wtsaf2yr
  )


# ------------------------------------------------------------
# CHECK CLEAN DATA
# ------------------------------------------------------------

dim(bmx_current_clean)
dim(bp_current_clean)
dim(a1c_current_clean)
dim(hdl_current_clean)
dim(trig_current_clean)



# ------------------------------------------------------------
# MERGE NHANES DATASETS
# ------------------------------------------------------------

current_analysis <- demo_current %>%
  left_join(
    bmx_current_clean,
    by = c("seqn", "year")
  ) %>%
  left_join(
    bp_current_clean,
    by = c("seqn", "year")
  ) %>%
  left_join(
    a1c_current_clean,
    by = c("seqn", "year")
  ) %>%
  left_join(
    hdl_current_clean,
    by = c("seqn", "year")
  ) %>%
  left_join(
    trig_current_clean,
    by = c("seqn", "year")
  )


# ------------------------------------------------------------
# DEFINE ANALYSIS POPULATION
# Adults age 20-64 with normal BMI (18.5-24.9)
# ------------------------------------------------------------

current_analysis <- current_analysis %>%
  filter(
    ridageyr >= 20,
    ridageyr <= 64,
    bmi >= 18.5,
    bmi <= 24.9
  ) %>%
  mutate(
    sex = case_when(
      riagendr == "Male" ~ "Male",
      riagendr == "Female" ~ "Female",
      TRUE ~ NA_character_
    )
  )


# ------------------------------------------------------------
# CHECK ANALYSIS SAMPLE
# ------------------------------------------------------------

dim(current_analysis)

current_analysis %>%
  summarise(
    Participants = n(),
    Min_Age = min(ridageyr, na.rm = TRUE),
    Max_Age = max(ridageyr, na.rm = TRUE),
    Min_BMI = min(bmi, na.rm = TRUE),
    Max_BMI = max(bmi, na.rm = TRUE)
  )




# ------------------------------------------------------------
# CREATE CARDIOMETABOLIC RISK INDICATORS
# ------------------------------------------------------------

current_analysis <- current_analysis %>%
  mutate(
    
    # High blood pressure:
    # systolic >= 130 OR diastolic >= 80
    bp_risk = case_when(
      is.na(avg_sbp) | is.na(avg_dbp) ~ NA_real_,
      avg_sbp >= 130 | avg_dbp >= 80 ~ 1,
      TRUE ~ 0
    ),
    
    # Elevated A1C: >= 5.7%
    a1c_risk = case_when(
      is.na(a1c) ~ NA_real_,
      a1c >= 5.7 ~ 1,
      TRUE ~ 0
    ),
    
    # Elevated triglycerides: >= 150 mg/dL
    triglyceride_risk = case_when(
      is.na(triglycerides) ~ NA_real_,
      triglycerides >= 150 ~ 1,
      TRUE ~ 0
    ),
    
    # Low HDL:
    # Male < 40 mg/dL
    # Female < 50 mg/dL
    hdl_risk = case_when(
      is.na(hdl) | is.na(sex) ~ NA_real_,
      sex == "Male" & hdl < 40 ~ 1,
      sex == "Female" & hdl < 50 ~ 1,
      TRUE ~ 0
    ),
    
    # High waist circumference:
    # Male > 102 cm
    # Female > 88 cm
    waist_risk = case_when(
      is.na(waist) | is.na(sex) ~ NA_real_,
      sex == "Male" & waist > 102 ~ 1,
      sex == "Female" & waist > 88 ~ 1,
      TRUE ~ 0
    )
  )


# ------------------------------------------------------------
# COUNT AVAILABLE RISK FACTORS
# ------------------------------------------------------------

current_analysis <- current_analysis %>%
  mutate(
    risk_variables_available =
      (!is.na(bp_risk)) +
      (!is.na(a1c_risk)) +
      (!is.na(triglyceride_risk)) +
      (!is.na(hdl_risk)) +
      (!is.na(waist_risk))
  )


# ------------------------------------------------------------
# KEEP PARTICIPANTS WITH ALL 5 RISK FACTORS
# ------------------------------------------------------------

current_complete <- current_analysis %>%
  filter(risk_variables_available == 5) %>%
  mutate(
    
    metabolic_risk_score =
      bp_risk +
      a1c_risk +
      triglyceride_risk +
      hdl_risk +
      waist_risk,
    
    hidden_risk = if_else(
      metabolic_risk_score >= 2,
      1,
      0
    ),
    
    hidden_risk_group = if_else(
      hidden_risk == 1,
      "Hidden Cardiometabolic Risk",
      "Lower Risk"
    )
  )


# ------------------------------------------------------------
# VALIDATE FINAL SAMPLE
# ------------------------------------------------------------

dim(current_complete)

current_complete %>%
  summarise(
    Participants = n(),
    BP_Risk = sum(bp_risk == 1),
    A1C_Risk = sum(a1c_risk == 1),
    Triglyceride_Risk = sum(triglyceride_risk == 1),
    HDL_Risk = sum(hdl_risk == 1),
    Waist_Risk = sum(waist_risk == 1),
    Hidden_Risk = sum(hidden_risk == 1)
  )

table(current_complete$hidden_risk)




# ------------------------------------------------------------
# CREATE DEMOGRAPHIC VARIABLES
# ------------------------------------------------------------

current_complete <- current_complete %>%
  mutate(
    
    # Race / ethnicity
    race_ethnicity = case_when(
      as.character(ridreth3) %in% c("1", "Mexican American") ~ "Mexican American",
      as.character(ridreth3) %in% c("2", "Other Hispanic") ~ "Other Hispanic",
      as.character(ridreth3) %in% c("3", "Non-Hispanic White") ~ "Non-Hispanic White",
      as.character(ridreth3) %in% c("4", "Non-Hispanic Black") ~ "Non-Hispanic Black",
      as.character(ridreth3) %in% c("6", "Non-Hispanic Asian") ~ "Non-Hispanic Asian",
      as.character(ridreth3) %in% c("7", "Other Race - Including Multi-Racial") ~
        "Other Race - Including Multi-Racial",
      TRUE ~ NA_character_
    ),
    
    # Education
    education = case_when(
      as.character(dmdeduc2) %in% c("1", "Less than 9th grade") ~
        "Less than 9th Grade",
      
      as.character(dmdeduc2) %in% c("2", "9-11th grade (Includes 12th grade with no diploma)") ~
        "9th-11th Grade",
      
      as.character(dmdeduc2) %in% c("3", "High school graduate/GED or equivalent") ~
        "High School / GED",
      
      as.character(dmdeduc2) %in% c("4", "Some college or AA degree") ~
        "Some College / AA",
      
      as.character(dmdeduc2) %in% c("5", "College graduate or above") ~
        "College Graduate or Above",
      
      TRUE ~ NA_character_
    ),
    
    # Family income-to-poverty ratio
    income_group = case_when(
      indfmpir < 1 ~ "Below Poverty",
      indfmpir >= 1 & indfmpir < 2 ~ "1.00-1.99 PIR",
      indfmpir >= 2 & indfmpir < 4 ~ "2.00-3.99 PIR",
      indfmpir >= 4 ~ "4.00+ PIR",
      TRUE ~ NA_character_
    )
  )


# ------------------------------------------------------------
# CHECK DEMOGRAPHIC VARIABLES
# ------------------------------------------------------------

dim(current_complete)

table(current_complete$race_ethnicity, useNA = "ifany")
table(current_complete$education, useNA = "ifany")
table(current_complete$income_group, useNA = "ifany")




# ------------------------------------------------------------
# CREATE AGE GROUP
# ------------------------------------------------------------

current_complete <- current_complete %>%
  mutate(
    age_group = case_when(
      ridageyr >= 20 & ridageyr <= 29 ~ "20-29",
      ridageyr >= 30 & ridageyr <= 39 ~ "30-39",
      ridageyr >= 40 & ridageyr <= 49 ~ "40-49",
      ridageyr >= 50 & ridageyr <= 64 ~ "50-64",
      TRUE ~ NA_character_
    )
  )


# ------------------------------------------------------------
# FINAL VALIDATION
# ------------------------------------------------------------

dim(current_complete)

current_complete %>%
  count(age_group)

current_complete %>%
  group_by(age_group) %>%
  summarise(
    Participants = n(),
    Hidden_Risk = sum(hidden_risk),
    Hidden_Risk_Percent = round(mean(hidden_risk) * 100, 1)
  )