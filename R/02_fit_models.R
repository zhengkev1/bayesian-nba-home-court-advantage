# 02_fit_models.R
# ------------------------------------------------------------------------------
# Fit the four Bayesian logistic-regression models with rethinking::ulam()
# (Stan, 4 chains x 4000 iterations) and save
#   - posterior summaries  -> results/m{1,3,4,7}_summary.csv
#   - fitted model objects -> models/*.rds   (large, git-ignored)
#
# Models (outcome: win ~ Bernoulli(p); see README for the full equations)
#   M1  team-specific home slopes, no team strength
#   M3  team intercepts + one league-wide home effect
#   M4  team strength - opponent strength + team-specific home deviation
#   M7  M1 + in-game turnovers and free-throw % (exploratory)
#
# Usage (from the repository root):
#   Rscript R/02_fit_models.R            # fit all four models
#   Rscript R/02_fit_models.R m4 m3      # fit only the listed models
#
# Requires: rethinking (>= 2.x) with cmdstanr or rstan; tidyverse.
# NOTE: the fitted objects are 1-2.5 GB each in memory/on disk, so each model is
# summarised, saved and removed before the next one is fitted.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(rethinking)
  library(dplyr)
  library(readr)
  library(tibble)
})

source("R/00_prepare_model_data.R")

dir.create("results", showWarnings = FALSE)
dir.create("models",  showWarnings = FALSE)

which_models <- commandArgs(trailingOnly = TRUE)
if (length(which_models) == 0) which_models <- c("m4", "m3", "m1", "m7")

# Helper: tidy precis() output in the format used in results/
write_summary <- function(fit, label, file, add_model_col = TRUE) {
  out <- precis(fit, depth = 2) %>%
    as.data.frame() %>%
    rownames_to_column("parameter") %>%
    as_tibble()
  if (add_model_col) {
    out <- out %>%
      mutate(model = label) %>%
      select(model, parameter, mean, sd, `5.5%`, `94.5%`, rhat, ess_bulk)
  }
  write_csv(out, file)
  invisible(out)
}

# --- Model 4: team strength + team-specific home deviation --------------------
# logit(p) = a + strength[team] - strength[opponent]
#            + (b_home + u_home[team]) * home + b_b2b * b2b
if ("m4" %in% which_models) {
  m4 <- ulam(
    alist(
      win ~ dbinom(1, p),
      logit(p) <- a +
        strength[team] -
        strength[opponent] +
        (b_home + u_home[team]) * home +
        b_b2b * b2b,

      strength[team] ~ dnorm(0, sigma_strength),
      u_home[team] ~ dnorm(0, sigma_home),

      a ~ dnorm(0, 1.5),
      b_home ~ dnorm(0, 1),
      b_b2b ~ dnorm(0, 1),

      sigma_strength ~ dexp(1),
      sigma_home ~ dexp(1)
    ),
    data = dat,
    chains = 4, cores = 4,
    iter = 4000, warmup = 2000,
    log_lik = TRUE
  )
  write_summary(m4, "Model 4: Strength + team home",
                "results/m4_summary.csv", add_model_col = FALSE)
  saveRDS(m4, "models/m4_strength_home.rds")
  rm(m4); gc()
}

# --- Model 3: team intercepts + league-wide home effect -----------------------
# logit(p) = a_team[team] + b_home * home + b_b2b * b2b
if ("m3" %in% which_models) {
  m3 <- ulam(
    alist(
      win ~ dbinom(1, p),
      logit(p) <- a_team[team] + b_home * home + b_b2b * b2b,

      a_team[team] ~ dnorm(a_bar, sigma_a),

      a_bar ~ dnorm(0, 1.5),
      sigma_a ~ dexp(1),

      b_home ~ dnorm(0, 1),
      b_b2b ~ dnorm(0, 1)
    ),
    data = dat,
    chains = 4, cores = 4,
    iter = 4000, warmup = 1500,
    log_lik = TRUE
  )
  write_summary(m3, "Model 3: Team intercepts", "results/m3_summary.csv")
  saveRDS(m3, "models/m3_team_intercept.rds")
  rm(m3); gc()
}

# --- Model 1: team-specific home slopes ---------------------------------------
# logit(p) = a + (b_home + u_team[team]) * home + b_b2b * b2b
if ("m1" %in% which_models) {
  m1 <- ulam(
    alist(
      win ~ dbinom(1, p),
      logit(p) <- a + (b_home + u_team[team]) * home + b_b2b * b2b,

      u_team[team] ~ dnorm(0, sigma_u),

      a ~ dnorm(0, 1.5),
      b_home ~ dnorm(0, 1),
      b_b2b ~ dnorm(0, 1),

      sigma_u ~ dexp(1)
    ),
    data = dat,
    chains = 4, cores = 4,
    iter = 4000, warmup = 1500,
    log_lik = TRUE
  )
  write_summary(m1, "Model 1: Team home slopes", "results/m1_summary.csv")
  saveRDS(m1, "models/m1_team_home.rds")
  rm(m1); gc()
}

# --- Model 7: exploratory model with turnovers and free-throw % ---------------
# logit(p) = a + (b_home + u_team[team]) * home + b_b2b * b2b
#            + b_tov * tov_z + b_ft * ft_pct_z
# Turnovers and free-throw % happen during the game, so they may partly
# *mediate* the home effect; this model is exploratory, not causal.
if ("m7" %in% which_models) {
  m7 <- ulam(
    alist(
      win ~ dbinom(1, p),

      logit(p) <- a +
        (b_home + u_team[team]) * home +
        b_b2b * b2b +
        b_tov * tov_z +
        b_ft * ft_pct_z,

      u_team[team] ~ dnorm(0, sigma_u),

      a ~ dnorm(0, 1.5),
      b_home ~ dnorm(0, 1),
      b_b2b ~ dnorm(0, 1),
      b_tov ~ dnorm(0, 1),
      b_ft ~ dnorm(0, 1),

      sigma_u ~ dexp(1)
    ),
    data = dat7,
    chains = 4, cores = 4,
    iter = 4000, warmup = 1000,
    log_lik = TRUE
  )
  write_summary(m7, "Model 7: Exploratory full model", "results/m7_summary.csv")
  saveRDS(m7, "models/m7_exploratory.rds")
  rm(m7); gc()
}
