# ============================================================
# 07 - FINAL FIGURES
# Beyond BMI: Hidden Cardiometabolic Risk
# ============================================================

library(nhanesdata)
library(dplyr)
library(survey)
library(ggplot2)
library(scales)


# ============================================================
# LOAD CURRENT ANALYSIS DATA
# ============================================================

source("R/01_data_preparation.R")


# ------------------------------------------------------------
# CREATE SURVEY DESIGN
# Fasting subsample weights are used because triglycerides
# are included in the cardiometabolic risk definition.
# ------------------------------------------------------------

figure_design <- create_design(
  current_complete,
  start_yr = 2021,
  end_yr = 2021,
  wt_type = "fasting"
)


# ============================================================
# LOAD SAVED RESULTS
# ============================================================

income_results <- read.csv(
  "results/weighted_income_prevalence.csv"
)

race_results <- read.csv(
  "results/weighted_risk_by_race.csv"
)

education_results <- read.csv(
  "results/weighted_risk_by_education.csv"
)

mortality_results <- read.csv(
  "results/mortality_by_hidden_risk.csv"
)


# ============================================================
# FIGURE 1
# Overall Survey-Weighted Hidden Cardiometabolic Risk
# ============================================================


# ------------------------------------------------------------
# CALCULATE OVERALL WEIGHTED PREVALENCE
# ------------------------------------------------------------

overall_hidden_risk <- svymean(
  ~hidden_risk,
  figure_design,
  na.rm = TRUE
)


overall_ci <- confint(
  overall_hidden_risk
)


figure1_data <- data.frame(
  
  group =
    "Normal-BMI Adults",
  
  prevalence =
    as.numeric(
      coef(overall_hidden_risk)
    ),
  
  lower =
    overall_ci[1, 1],
  
  upper =
    overall_ci[1, 2]
)


figure1_subtitle <- paste0(
  
  "Survey-weighted prevalence: ",
  
  percent(
    figure1_data$prevalence,
    accuracy = 0.1
  ),
  
  " (95% CI: ",
  
  percent(
    figure1_data$lower,
    accuracy = 0.1
  ),
  
  "–",
  
  percent(
    figure1_data$upper,
    accuracy = 0.1
  ),
  
  ")"
)


figure1 <- ggplot(
  
  figure1_data,
  
  aes(
    x = group,
    y = prevalence
  )
  
) +
  
  geom_col(
    width = 0.55,
    fill = "#2C7FB8"
  ) +
  
  geom_errorbar(
    aes(
      ymin = lower,
      ymax = upper
    ),
    width = 0.12,
    linewidth = 0.8
  ) +
  
  geom_text(
    aes(
      label = percent(
        prevalence,
        accuracy = 0.1
      )
    ),
    vjust = -0.7,
    size = 6,
    fontface = "bold"
  ) +
  
  scale_y_continuous(
    labels = percent_format(
      accuracy = 1
    ),
    limits = c(0, 0.22),
    expand = c(0, 0)
  ) +
  
  labs(
    title =
      "Hidden Cardiometabolic Risk Among Normal-BMI Adults",
    
    subtitle =
      figure1_subtitle,
    
    x = NULL,
    
    y = "Prevalence",
    
    caption =
      "NHANES | Survey-weighted using fasting subsample weights"
  ) +
  
  theme_minimal(
    base_size = 13
  ) +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 16
    ),
    
    plot.subtitle = element_text(
      size = 12
    ),
    
    axis.text.x = element_text(
      face = "bold"
    ),
    
    panel.grid.major.x =
      element_blank(),
    
    panel.grid.minor =
      element_blank()
  )


figure1


ggsave(
  "figures/01_overall_hidden_risk.png",
  figure1,
  width = 8,
  height = 6,
  dpi = 300
)


# ============================================================
# FIGURE 2
# Survey-Weighted Cardiometabolic Risk Factors
# ============================================================


# ------------------------------------------------------------
# CALCULATE WEIGHTED RISK-FACTOR PREVALENCE
# ------------------------------------------------------------

risk_factor_estimates <- svymean(
  
  ~bp_risk +
    a1c_risk +
    triglyceride_risk +
    hdl_risk +
    waist_risk,
  
  figure_design,
  
  na.rm = TRUE
)


figure2_data <- data.frame(
  
  risk_factor = c(
    "High Blood Pressure",
    "High A1C",
    "High Triglycerides",
    "Low HDL",
    "High Waist Circumference"
  ),
  
  prevalence =
    as.numeric(
      coef(risk_factor_estimates)
    )
)


figure2_data <- figure2_data %>%
  
  arrange(
    prevalence
  ) %>%
  
  mutate(
    
    risk_factor = factor(
      risk_factor,
      levels = risk_factor
    )
  )


figure2 <- ggplot(
  
  figure2_data,
  
  aes(
    x = prevalence,
    y = risk_factor
  )
  
) +
  
  geom_col(
    width = 0.65,
    fill = "#2C7FB8"
  ) +
  
  geom_text(
    aes(
      label = percent(
        prevalence,
        accuracy = 0.1
      )
    ),
    hjust = -0.15,
    size = 4.5,
    fontface = "bold"
  ) +
  
  scale_x_continuous(
    labels = percent_format(
      accuracy = 1
    ),
    limits = c(0, 0.22),
    expand = c(0, 0)
  ) +
  
  labs(
    title =
      "Cardiometabolic Risk Can Be Present at a Normal BMI",
    
    subtitle =
      "Survey-weighted prevalence of individual risk factors",
    
    x = "Prevalence",
    
    y = NULL,
    
    caption =
      "NHANES | Survey-weighted using fasting subsample weights"
  ) +
  
  theme_minimal(
    base_size = 13
  ) +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 16
    ),
    
    plot.subtitle = element_text(
      size = 12
    ),
    
    panel.grid.major.y =
      element_blank(),
    
    panel.grid.minor =
      element_blank()
  )


figure2


ggsave(
  "figures/02_cardiometabolic_risk_factors.png",
  figure2,
  width = 8,
  height = 6,
  dpi = 300
)


# ============================================================
# FIGURE 3
# Health Equity Differences in Hidden Cardiometabolic Risk
# ============================================================


figure3_income <- income_results %>%
  
  transmute(
    
    domain =
      "Income",
    
    group =
      income_group,
    
    prevalence =
      Hidden_Risk_Prevalence,
    
    lower =
      Hidden_Risk_Prevalence_low,
    
    upper =
      Hidden_Risk_Prevalence_upp
  )


figure3_race <- race_results %>%
  
  transmute(
    
    domain =
      "Race / Ethnicity",
    
    group =
      race_ethnicity,
    
    prevalence =
      Hidden_Risk_Prevalence,
    
    lower =
      Hidden_Risk_Prevalence_low,
    
    upper =
      Hidden_Risk_Prevalence_upp
  )


figure3_education <- education_results %>%
  
  transmute(
    
    domain =
      "Education",
    
    group =
      education,
    
    prevalence =
      Hidden_Risk_Prevalence,
    
    lower =
      Hidden_Risk_Prevalence_low,
    
    upper =
      Hidden_Risk_Prevalence_upp
  )


figure3_data <- bind_rows(
  
  figure3_income,
  figure3_race,
  figure3_education
  
) %>%
  
  mutate(
    
    # Prevalence cannot be below 0%
    lower_plot =
      pmax(
        lower,
        0
      ),
    
    
    # Shorter label for graph
    group = case_when(
      
      group ==
        "Other Race - Including Multi-Racial" ~
        "Other / Multiracial",
      
      TRUE ~
        group
    )
  )


figure3 <- ggplot(
  
  figure3_data,
  
  aes(
    x = prevalence,
    y = reorder(
      group,
      prevalence
    )
  )
  
) +
  
  geom_errorbar(
    aes(
      xmin = lower_plot,
      xmax = upper
    ),
    width = 0.18,
    linewidth = 0.7,
    orientation = "y"
  ) +
  
  geom_point(
    size = 3
  ) +
  
  geom_text(
    aes(
      label = percent(
        prevalence,
        accuracy = 0.1
      )
    ),
    hjust = -0.25,
    size = 3.8
  ) +
  
  facet_grid(
    domain ~ .,
    scales = "free_y",
    space = "free_y"
  ) +
  
  scale_x_continuous(
    labels = percent_format(
      accuracy = 1
    ),
    limits = c(0, 0.58),
    expand = expansion(
      mult = c(
        0,
        0.02
      )
    )
  ) +
  
  labs(
    title =
      "Hidden Cardiometabolic Risk Varies Across Population Groups",
    
    subtitle =
      "Survey-weighted prevalence with 95% confidence intervals",
    
    x = "Prevalence",
    
    y = NULL,
    
    caption =
      "NHANES | Survey-weighted using fasting subsample weights"
  ) +
  
  theme_minimal(
    base_size = 12
  ) +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 16
    ),
    
    plot.subtitle = element_text(
      size = 12
    ),
    
    strip.text = element_text(
      face = "bold",
      size = 12
    ),
    
    panel.grid.major.y =
      element_blank(),
    
    panel.grid.minor =
      element_blank()
  )


figure3


ggsave(
  "figures/03_health_equity_prevalence.png",
  figure3,
  width = 9,
  height = 9,
  dpi = 300
)


# ============================================================
# FIGURE 4
# Mortality by Hidden Cardiometabolic Risk
# ============================================================


figure4_data <- mortality_results %>%
  
  mutate(
    
    mortality =
      Mortality_Percent / 100,
    
    hidden_risk_group = factor(
      
      hidden_risk_group,
      
      levels = c(
        "Lower Risk",
        "Hidden Cardiometabolic Risk"
      )
    )
  )


figure4 <- ggplot(
  
  figure4_data,
  
  aes(
    x = hidden_risk_group,
    y = mortality
  )
  
) +
  
  geom_col(
    width = 0.55,
    fill = "#2C7FB8"
  ) +
  
  geom_text(
    aes(
      label = percent(
        mortality,
        accuracy = 0.1
      )
    ),
    vjust = -0.6,
    size = 5,
    fontface = "bold"
  ) +
  
  scale_y_continuous(
    labels = percent_format(
      accuracy = 1
    ),
    limits = c(0, 0.11),
    expand = c(0, 0)
  ) +
  
  labs(
    title =
      "Mortality Was Higher Among Adults With Hidden Risk",
    
    subtitle =
      "Unadjusted mortality among normal-BMI adults",
    
    x = NULL,
    
    y = "Mortality",
    
    caption =
      "Mortality-linked NHANES sample | Descriptive, unadjusted percentages"
  ) +
  
  theme_minimal(
    base_size = 13
  ) +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 16
    ),
    
    plot.subtitle = element_text(
      size = 12
    ),
    
    axis.text.x = element_text(
      face = "bold"
    ),
    
    panel.grid.major.x =
      element_blank(),
    
    panel.grid.minor =
      element_blank()
  )


figure4


ggsave(
  "figures/04_mortality_by_hidden_risk.png",
  figure4,
  width = 8,
  height = 6,
  dpi = 300
)


# ============================================================
# FINAL FIGURE VALIDATION
# ============================================================

cat(
  "\n---------------------------------------------\n"
)

cat(
  "FINAL FIGURES COMPLETE\n"
)

cat(
  "---------------------------------------------\n"
)

cat(
  "Figure 1: Overall hidden risk\n"
)

cat(
  "Figure 2: Individual risk factors\n"
)

cat(
  "Figure 3: Health equity prevalence\n"
)

cat(
  "Figure 4: Mortality by hidden risk\n"
)

cat(
  "---------------------------------------------\n"
)