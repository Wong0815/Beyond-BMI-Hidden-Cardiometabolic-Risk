# ============================================================
# 02 - MORTALITY ANALYSIS
# Beyond BMI: Hidden Cardiometabolic Risk
# ============================================================

library(nhanesdata)
library(dplyr)
library(survival)


# ------------------------------------------------------------
# ANALYSIS YEARS
# ------------------------------------------------------------

mortality_years <- c(
  2005, 2007, 2009, 2011,
  2013, 2015, 2017
)


# ------------------------------------------------------------
# LOAD NHANES DATA
# ------------------------------------------------------------

demo_all <- read_nhanes("demo")
bmx_all  <- read_nhanes("bmx")
bpx_all  <- read_nhanes("bpx")
a1c_all  <- read_nhanes("ghb")
hdl_all  <- read_nhanes("hdl")
trig_all <- read_nhanes("trigly")


# ------------------------------------------------------------
# KEEP 2005-2017 CYCLES
# ------------------------------------------------------------

demo_mort <- demo_all %>%
  filter(year %in% mortality_years)

bmx_mort <- bmx_all %>%
  filter(year %in% mortality_years)

bpx_mort <- bpx_all %>%
  filter(year %in% mortality_years)

a1c_mort <- a1c_all %>%
  filter(year %in% mortality_years)

hdl_mort <- hdl_all %>%
  filter(year %in% mortality_years)

trig_mort <- trig_all %>%
  filter(year %in% mortality_years)


# ------------------------------------------------------------
# CLEAN BODY MEASUREMENTS
# ------------------------------------------------------------

bmx_mort_clean <- bmx_mort %>%
  select(
    seqn,
    year,
    bmi = bmxbmi,
    waist = bmxwaist
  )


# ------------------------------------------------------------
# CLEAN BLOOD PRESSURE
# Average all available BP measurements
# ------------------------------------------------------------

bpx_mort_clean <- bpx_mort %>%
  mutate(
    
    avg_sbp = rowMeans(
      across(
        any_of(
          c(
            "bpxsy1",
            "bpxsy2",
            "bpxsy3",
            "bpxsy4"
          )
        )
      ),
      na.rm = TRUE
    ),
    
    avg_dbp = rowMeans(
      across(
        any_of(
          c(
            "bpxdi1",
            "bpxdi2",
            "bpxdi3",
            "bpxdi4"
          )
        )
      ),
      na.rm = TRUE
    )
  ) %>%
  
  mutate(
    
    avg_sbp = ifelse(
      is.nan(avg_sbp),
      NA,
      avg_sbp
    ),
    
    avg_dbp = ifelse(
      is.nan(avg_dbp),
      NA,
      avg_dbp
    )
  ) %>%
  
  select(
    seqn,
    year,
    avg_sbp,
    avg_dbp
  )


# ------------------------------------------------------------
# CLEAN A1C
# ------------------------------------------------------------

a1c_mort_clean <- a1c_mort %>%
  select(
    seqn,
    year,
    a1c = lbxgh
  )


# ------------------------------------------------------------
# CLEAN HDL
# ------------------------------------------------------------

hdl_mort_clean <- hdl_mort %>%
  select(
    seqn,
    year,
    hdl = lbdhdd
  )


# ------------------------------------------------------------
# CLEAN TRIGLYCERIDES
# Variable names differ across NHANES cycles.
# Use whichever triglyceride variable is available.
# ------------------------------------------------------------

trig_mort_clean <- trig_mort %>%
  mutate(
    
    triglycerides = coalesce(
      lbxtlg,
      lbxtr
    )
  ) %>%
  
  select(
    seqn,
    year,
    triglycerides,
    wtsaf2yr
  )


# ------------------------------------------------------------
# MERGE NHANES DATA
# ------------------------------------------------------------

historical_analysis <- demo_mort %>%
  
  left_join(
    bmx_mort_clean,
    by = c("seqn", "year")
  ) %>%
  
  left_join(
    bpx_mort_clean,
    by = c("seqn", "year")
  ) %>%
  
  left_join(
    a1c_mort_clean,
    by = c("seqn", "year")
  ) %>%
  
  left_join(
    hdl_mort_clean,
    by = c("seqn", "year")
  ) %>%
  
  left_join(
    trig_mort_clean,
    by = c("seqn", "year")
  )


# ------------------------------------------------------------
# DEFINE NORMAL-BMI ADULT POPULATION
# Age 20-64
# BMI 18.5-24.9
# ------------------------------------------------------------

historical_analysis <- historical_analysis %>%
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
# CREATE CARDIOMETABOLIC RISK INDICATORS
# ------------------------------------------------------------

historical_analysis <- historical_analysis %>%
  mutate(
    
    # High blood pressure
    bp_risk = case_when(
      
      is.na(avg_sbp) |
        is.na(avg_dbp) ~ NA_real_,
      
      avg_sbp >= 130 |
        avg_dbp >= 80 ~ 1,
      
      TRUE ~ 0
    ),
    
    
    # Elevated A1C
    a1c_risk = case_when(
      
      is.na(a1c) ~ NA_real_,
      
      a1c >= 5.7 ~ 1,
      
      TRUE ~ 0
    ),
    
    
    # Elevated triglycerides
    triglyceride_risk = case_when(
      
      is.na(triglycerides) ~ NA_real_,
      
      triglycerides >= 150 ~ 1,
      
      TRUE ~ 0
    ),
    
    
    # Low HDL
    hdl_risk = case_when(
      
      is.na(hdl) |
        is.na(sex) ~ NA_real_,
      
      sex == "Male" &
        hdl < 40 ~ 1,
      
      sex == "Female" &
        hdl < 50 ~ 1,
      
      TRUE ~ 0
    ),
    
    
    # High waist circumference
    waist_risk = case_when(
      
      is.na(waist) |
        is.na(sex) ~ NA_real_,
      
      sex == "Male" &
        waist > 102 ~ 1,
      
      sex == "Female" &
        waist > 88 ~ 1,
      
      TRUE ~ 0
    )
  )


# ------------------------------------------------------------
# REQUIRE ALL FIVE RISK FACTORS
# ------------------------------------------------------------

historical_analysis <- historical_analysis %>%
  mutate(
    
    n_available =
      (!is.na(bp_risk)) +
      (!is.na(a1c_risk)) +
      (!is.na(triglyceride_risk)) +
      (!is.na(hdl_risk)) +
      (!is.na(waist_risk))
  ) %>%
  
  filter(
    n_available == 5
  ) %>%
  
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
    ),
    
    
    hidden_risk_group = factor(
      hidden_risk_group,
      levels = c(
        "Lower Risk",
        "Hidden Cardiometabolic Risk"
      )
    )
  )


# ============================================================
# LINKED MORTALITY DATA
# CDC 2019 PUBLIC-USE LINKED MORTALITY FILES
#
# Mortality files are stored locally in the data folder.
# ============================================================


# ------------------------------------------------------------
# FUNCTION TO READ ONE NHANES MORTALITY FILE
# ------------------------------------------------------------

read_mortality_file <- function(year) {
  
  end_year <- year + 1
  
  
  # Build local file path
  file_path <- paste0(
    "data/NHANES_",
    year,
    "_",
    end_year,
    "_MORT_2019_PUBLIC.dat"
  )
  
  
  # Make sure the mortality file exists
  if (!file.exists(file_path)) {
    
    stop(
      paste(
        "Mortality file not found:",
        file_path
      )
    )
  }
  
  
  # Read fixed-width CDC mortality file
  mortality_file <- read.fwf(
    
    file = file_path,
    
    widths = c(
      6,   # SEQN
      8,   # unused
      1,   # ELIGSTAT
      1,   # MORTSTAT
      3,   # UCOD_LEADING
      1,   # DIABETES
      1,   # HYPERTEN
      21,  # unused
      3,   # PERMTH_INT
      3    # PERMTH_EXM
    ),
    
    col.names = c(
      "seqn",
      "unused1",
      "eligstat",
      "mortstat",
      "ucod_leading",
      "diabetes",
      "hyperten",
      "unused2",
      "permth_int",
      "permth_exm"
    ),
    
    colClasses = "character",
    
    stringsAsFactors = FALSE
  )
  
  
  # Keep mortality-linkage eligible participants first.
  # Ineligible participants have blank mortality fields.
  mortality_file <- mortality_file %>%
    
    filter(
      trimws(eligstat) == "1"
    ) %>%
    
    transmute(
      
      year = year,
      
      seqn =
        as.integer(
          trimws(seqn)
        ),
      
      eligstat =
        as.integer(
          trimws(eligstat)
        ),
      
      mortstat =
        as.integer(
          trimws(mortstat)
        ),
      
      ucod_leading =
        trimws(
          ucod_leading
        ),
      
      diabetes =
        suppressWarnings(
          as.integer(
            trimws(diabetes)
          )
        ),
      
      hyperten =
        suppressWarnings(
          as.integer(
            trimws(hyperten)
          )
        ),
      
      permth_int =
        suppressWarnings(
          as.integer(
            trimws(permth_int)
          )
        ),
      
      permth_exm =
        suppressWarnings(
          as.integer(
            trimws(permth_exm)
          )
        )
    )
  
  
  return(
    mortality_file
  )
}


# ------------------------------------------------------------
# READ ALL 2005-2017 MORTALITY FILES
# ------------------------------------------------------------

mortality <- bind_rows(
  
  lapply(
    mortality_years,
    read_mortality_file
  )
)


# ------------------------------------------------------------
# CLEAN MORTALITY DATA
#
# Follow-up from MEC examination is used because
# the health measurements came from the examination.
# ------------------------------------------------------------

mortality_clean <- mortality %>%
  
  transmute(
    
    seqn,
    
    year,
    
    mortstat,
    
    followup_months =
      permth_exm
  )


# ------------------------------------------------------------
# JOIN MORTALITY TO CARDIOMETABOLIC DATA
# ------------------------------------------------------------

mortality_analysis <- historical_analysis %>%
  
  inner_join(
    mortality_clean,
    by = c(
      "seqn",
      "year"
    )
  ) %>%
  
  filter(
    !is.na(mortstat),
    !is.na(followup_months),
    followup_months > 0
  ) %>%
  
  mutate(
    
    mortality_text = case_when(
      
      mortstat == 1 ~ "Deceased",
      
      mortstat == 0 ~ "Alive",
      
      TRUE ~ NA_character_
    ),
    
    
    death = if_else(
      mortstat == 1,
      1,
      0
    ),
    
    
    followup_years =
      followup_months / 12
  )


# ------------------------------------------------------------
# VALIDATE MORTALITY COHORT
# ------------------------------------------------------------

dim(
  mortality_analysis
)


table(
  mortality_analysis$year
)


table(
  mortality_analysis$death
)


table(
  mortality_analysis$n_available
)


mortality_analysis %>%
  summarise(
    
    Participants = n(),
    
    Deaths =
      sum(death),
    
    Hidden_Risk =
      sum(hidden_risk),
    
    Lower_Risk =
      sum(hidden_risk == 0),
    
    Min_Age =
      min(ridageyr),
    
    Max_Age =
      max(ridageyr),
    
    Min_BMI =
      min(bmi),
    
    Max_BMI =
      max(bmi),
    
    Min_Followup =
      min(followup_years),
    
    Max_Followup =
      max(followup_years)
  )


# ============================================================
# DESCRIPTIVE MORTALITY
# ============================================================

mortality_summary <- mortality_analysis %>%
  
  group_by(
    hidden_risk_group
  ) %>%
  
  summarise(
    
    Participants =
      n(),
    
    Deaths =
      sum(death),
    
    Mortality_Percent =
      round(
        mean(death) * 100,
        2
      ),
    
    .groups = "drop"
  )


print(
  mortality_summary
)


# ------------------------------------------------------------
# SAVE DESCRIPTIVE MORTALITY RESULTS
# ------------------------------------------------------------

write.csv(
  
  mortality_summary,
  
  "results/mortality_by_hidden_risk.csv",
  
  row.names = FALSE
)


# ============================================================
# COX PROPORTIONAL HAZARDS MODELS
# ============================================================


# ------------------------------------------------------------
# UNADJUSTED MODEL
# ------------------------------------------------------------

cox_unadjusted <- coxph(
  
  Surv(
    followup_years,
    death
  ) ~
    hidden_risk_group,
  
  data =
    mortality_analysis
)


summary(
  cox_unadjusted
)


# ------------------------------------------------------------
# ADJUSTED MODEL
# Age + sex + BMI
# ------------------------------------------------------------

cox_adjusted <- coxph(
  
  Surv(
    followup_years,
    death
  ) ~
    hidden_risk_group +
    ridageyr +
    sex +
    bmi,
  
  data =
    mortality_analysis
)


summary(
  cox_adjusted
)


# ------------------------------------------------------------
# FORMAT ADJUSTED COX RESULTS
# ------------------------------------------------------------

cox_summary <- summary(
  cox_adjusted
)


cox_results <- data.frame(
  
  term =
    rownames(
      cox_summary$coefficients
    ),
  
  
  Hazard_Ratio =
    round(
      
      cox_summary$conf.int[
        ,
        "exp(coef)"
      ],
      
      2
    ),
  
  
  CI_Lower =
    round(
      
      cox_summary$conf.int[
        ,
        "lower .95"
      ],
      
      2
    ),
  
  
  CI_Upper =
    round(
      
      cox_summary$conf.int[
        ,
        "upper .95"
      ],
      
      2
    ),
  
  
  P_Value =
    round(
      
      cox_summary$coefficients[
        ,
        "Pr(>|z|)"
      ],
      
      4
    )
)


print(
  cox_results
)


# ------------------------------------------------------------
# SAVE COX RESULTS
# ------------------------------------------------------------

write.csv(
  
  cox_results,
  
  "results/cox_mortality_results.csv",
  
  row.names = FALSE
)


# ============================================================
# FINAL VALIDATION
# ============================================================

cat(
  "\n---------------------------------------------\n"
)


cat(
  "MORTALITY ANALYSIS VALIDATION\n"
)


cat(
  "---------------------------------------------\n"
)


cat(
  "Participants:",
  nrow(mortality_analysis),
  "\n"
)


cat(
  "Deaths:",
  sum(mortality_analysis$death),
  "\n"
)


cat(
  "Hidden risk:",
  sum(mortality_analysis$hidden_risk),
  "\n"
)


cat(
  "Lower risk:",
  sum(mortality_analysis$hidden_risk == 0),
  "\n\n"
)


print(
  mortality_summary
)


cat(
  "\nAdjusted Cox Model:\n"
)


print(
  cox_results
)