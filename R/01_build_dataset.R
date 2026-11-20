# 01_build_dataset.R
# ------------------------------------------------------------------------------
# Build the team-game dataset used in the models.
#
# Input : data/raw/game.csv   (the `game.csv` table from the Kaggle dataset
#         "Basketball Data" by Wyatt Walsh; NOT included in this repository,
#         see README -> "Data")
# Output: data/team_game_data.csv   (one row per team per game; 9,840 rows)
#
# Run from the repository root:   Rscript R/01_build_dataset.R
# A different input/output path can be given:
#   Rscript R/01_build_dataset.R path/to/game.csv path/to/output.csv
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

args <- commandArgs(trailingOnly = TRUE)
in_path  <- if (length(args) >= 1) args[1] else "data/raw/game.csv"
out_path <- if (length(args) >= 2) args[2] else "data/team_game_data.csv"

games_raw <- read_csv(in_path, show_col_types = FALSE)

# --- 1. Assign each game to a regular season by date --------------------------
# The raw table has no clean season label, so seasons are defined by the dates
# of the first and last regular-season game.
season_dates <- tibble(
  actual_season = c("14_15", "15_16", "16_17", "17_18", "18_19"),
  season_start = as.Date(c("2014-10-28", "2015-10-27", "2016-10-25",
                           "2017-10-17", "2018-10-16")),
  season_end   = as.Date(c("2015-04-15", "2016-04-13", "2017-04-12",
                           "2018-04-11", "2019-04-10"))
)

games_raw <- games_raw %>%
  mutate(game_date = as.Date(game_date))

games_with_season <- games_raw %>%
  left_join(
    season_dates,
    by = join_by(game_date >= season_start, game_date <= season_end)
  )

# The project analyses four regular seasons: 2014-15 through 2017-18.
keep_seasons <- c("14_15", "15_16", "16_17", "17_18")

games_filtered <- games_with_season %>%
  filter(
    actual_season %in% keep_seasons,
    season_type == "Regular Season"
  )

# --- 2. One row per game  ->  two rows per game (home view, away view) --------
home_games <- games_filtered %>%
  transmute(
    game_id, game_date, actual_season, season_type,

    team_id           = team_id_home,
    team_abbreviation = team_abbreviation_home,
    team_name         = team_name_home,

    opponent_id           = team_id_away,
    opponent_abbreviation = team_abbreviation_away,
    opponent_name         = team_name_away,

    home = 1,
    win  = if_else(pts_home > pts_away, 1, 0),

    team_score = pts_home,
    opp_score  = pts_away,

    fgm = fgm_home, fga = fga_home, fg_pct = fg_pct_home,
    fg3m = fg3m_home, fg3a = fg3a_home, fg3_pct = fg3_pct_home,
    ftm = ftm_home, fta = fta_home, ft_pct = ft_pct_home,
    oreb = oreb_home, dreb = dreb_home, reb = reb_home,
    ast = ast_home, stl = stl_home, blk = blk_home,
    tov = tov_home, pf = pf_home,
    plus_minus = plus_minus_home
  )

away_games <- games_filtered %>%
  transmute(
    game_id, game_date, actual_season, season_type,

    team_id           = team_id_away,
    team_abbreviation = team_abbreviation_away,
    team_name         = team_name_away,

    opponent_id           = team_id_home,
    opponent_abbreviation = team_abbreviation_home,
    opponent_name         = team_name_home,

    home = 0,
    win  = if_else(pts_away > pts_home, 1, 0),

    team_score = pts_away,
    opp_score  = pts_home,

    fgm = fgm_away, fga = fga_away, fg_pct = fg_pct_away,
    fg3m = fg3m_away, fg3a = fg3a_away, fg3_pct = fg3_pct_away,
    ftm = ftm_away, fta = fta_away, ft_pct = ft_pct_away,
    oreb = oreb_away, dreb = dreb_away, reb = reb_away,
    ast = ast_away, stl = stl_away, blk = blk_away,
    tov = tov_away, pf = pf_away,
    plus_minus = plus_minus_away
  )

team_game_data <- bind_rows(home_games, away_games) %>%
  arrange(team_id, actual_season, game_date, game_id)

# --- 3. Schedule variables: rest days and back-to-back indicator --------------
# days_since_last is computed within team and season, so the first game of a
# season has days_since_last = NA and b2b = 0.
team_game_data <- team_game_data %>%
  group_by(team_id, actual_season) %>%
  arrange(game_date, game_id, .by_group = TRUE) %>%
  mutate(
    days_since_last = as.numeric(game_date - lag(game_date)),
    b2b = if_else(!is.na(days_since_last) & days_since_last == 1, 1, 0)
  ) %>%
  ungroup()

print(count(team_game_data, actual_season))

write_csv(team_game_data, out_path)
message("Wrote ", nrow(team_game_data), " rows to ", out_path)
