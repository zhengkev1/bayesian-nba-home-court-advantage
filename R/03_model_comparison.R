# 03_model_comparison.R
# ------------------------------------------------------------------------------
# Compare the fitted models with WAIC (lower = better expected out-of-sample
# predictive performance) and write results/waic_table.csv.
#
# Reads the fitted objects saved by 02_fit_models.R (models/*.rds). Each object
# is loaded, scored, and removed one at a time because they are very large.
#
# Usage (from the repository root):   Rscript R/03_model_comparison.R
#
# The committed results/waic_table.csv comes from the original run, in which
# only Models 3, 4 and 7 were saved and scored. Re-running this script scores
# every model file that exists in models/, so Model 1 will appear if m1 was fit.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(rethinking)
  library(dplyr)
  library(readr)
  library(tibble)
})

source("R/00_prepare_model_data.R")   # for nrow(nba_model)

model_files <- c(
  "Model 1: Team home slopes"       = "models/m1_team_home.rds",
  "Model 3: Team intercepts"        = "models/m3_team_intercept.rds",
  "Model 4: Strength + team home"   = "models/m4_strength_home.rds",
  "Model 7: Exploratory full model" = "models/m7_exploratory.rds"
)
model_files <- model_files[file.exists(model_files)]
stopifnot(length(model_files) > 0)

rows <- lapply(names(model_files), function(label) {
  fit <- readRDS(model_files[[label]])
  w <- WAIC(fit)
  rm(fit); gc()
  tibble(
    model   = label,
    WAIC    = w$WAIC,
    lppd    = w$lppd,
    penalty = w$penalty,
    std_err = w$std_err
  )
})

waic_table <- bind_rows(rows) %>%
  arrange(WAIC) %>%
  mutate(
    dWAIC        = WAIC - min(WAIC),
    WAIC_per_obs = WAIC / nrow(nba_model)
  )

print(waic_table)
write_csv(waic_table, "results/waic_table.csv")
