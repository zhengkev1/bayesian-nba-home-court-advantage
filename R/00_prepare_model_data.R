# 00_prepare_model_data.R
# ------------------------------------------------------------------------------
# Shared data preparation for all models. Sourced by 02_fit_models.R and
# 03_model_comparison.R; it can also be run on its own to inspect the data that
# goes into Stan.
#
# Creates in the calling environment:
#   nba_model  - model data frame (one row per team-game, with integer team ids)
#   team_key   - lookup table: team_index (1-30) <-> team_id / abbreviation / name
#   dat        - list passed to rethinking::ulam() for Models 1, 3 and 4
#   dat7       - list passed to ulam() for Model 7 (same rows; kept as in the
#                original analysis)
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

data_path <- if (exists("DATA_PATH")) DATA_PATH else "data/team_game_data.csv"

nba_raw <- read_csv(data_path, show_col_types = FALSE) %>%
  mutate(game_date = as.Date(game_date))

# Keep regular-season games in the four analysed seasons and the columns the
# models use. (The date filter reproduces the season definitions in
# 01_build_dataset.R; the 18_19 window is included for completeness but
# contains no games in this dataset.)
nba_clean <- nba_raw %>%
  mutate(
    nba_season = case_when(
      game_date >= as.Date("2014-10-28") & game_date <= as.Date("2015-04-15") ~ "14_15",
      game_date >= as.Date("2015-10-27") & game_date <= as.Date("2016-04-13") ~ "15_16",
      game_date >= as.Date("2016-10-25") & game_date <= as.Date("2017-04-12") ~ "16_17",
      game_date >= as.Date("2017-10-17") & game_date <= as.Date("2018-04-11") ~ "17_18",
      game_date >= as.Date("2018-10-16") & game_date <= as.Date("2019-04-10") ~ "18_19",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(
    nba_season %in% c("14_15", "15_16", "16_17", "17_18", "18_19"),
    season_type == "Regular Season"
  ) %>%
  select(
    game_id, game_date, nba_season,
    team_id, team_abbreviation, team_name,
    opponent_id, opponent_abbreviation, opponent_name,
    home, win, b2b,
    team_score, opp_score,
    tov, ft_pct
  ) %>%
  drop_na(win, home, b2b, team_id, opponent_id)

# Integer team index 1..30 (ordered by NBA team_id). The same index is used for
# the team and the opponent so that strength[team] - strength[opponent] works.
#
# One row per team_id, using the most recent name/abbreviation. This matters:
# the Clippers appear as "Los Angeles Clippers" in 2014-15 and "LA Clippers"
# afterwards under the SAME team_id, so de-duplicating on (id, abbreviation,
# name) yields 31 rows, and joining on team_id then duplicates every Clippers
# game (see README, "Known issue in the original run").
team_key <- nba_clean %>%
  arrange(team_id, desc(game_date)) %>%
  group_by(team_id) %>%
  slice(1) %>%
  ungroup() %>%
  select(team_id, team_abbreviation, team_name) %>%
  arrange(team_id) %>%
  mutate(team_index = row_number())

stopifnot(nrow(team_key) == n_distinct(nba_clean$team_id))

nba_model <- nba_clean %>%
  left_join(team_key %>% select(team_id, team_index), by = "team_id") %>%
  rename(team = team_index) %>%
  left_join(
    team_key %>% select(team_id, team_index),
    by = c("opponent_id" = "team_id")
  ) %>%
  rename(opponent = team_index) %>%
  mutate(
    tov_z    = as.numeric(scale(tov)),     # turnovers, standardised
    ft_pct_z = as.numeric(scale(ft_pct))   # free-throw %, standardised
  )

# Guards: the joins must not change the number of rows, and there are 30 teams.
stopifnot(nrow(nba_model) == nrow(nba_clean))
N_team <- n_distinct(nba_model$team)
stopifnot(N_team == 30)

dat <- list(
  N        = nrow(nba_model),
  win      = nba_model$win,
  home     = nba_model$home,
  b2b      = nba_model$b2b,
  team     = nba_model$team,
  opponent = nba_model$opponent,
  N_team   = N_team,
  tov_z    = nba_model$tov_z,
  ft_pct_z = nba_model$ft_pct_z
)

# Model 7 data: identical rows; standardisation is redone after dropping NAs,
# exactly as in the original analysis.
nba_model7 <- nba_model %>%
  drop_na(win, home, b2b, team, tov, ft_pct) %>%
  mutate(
    tov_z    = as.numeric(scale(tov)),
    ft_pct_z = as.numeric(scale(ft_pct))
  )

dat7 <- list(
  N        = nrow(nba_model7),
  win      = nba_model7$win,
  home     = nba_model7$home,
  b2b      = nba_model7$b2b,
  team     = nba_model7$team,
  N_team   = max(nba_model7$team),
  tov_z    = nba_model7$tov_z,
  ft_pct_z = nba_model7$ft_pct_z
)
