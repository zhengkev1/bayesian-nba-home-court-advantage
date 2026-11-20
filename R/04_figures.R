# 04_figures.R
# ------------------------------------------------------------------------------
# Figures built from the committed result tables (no model re-fitting needed):
#   figures/waic_comparison.png   WAIC (+/- SE) for the models in waic_table.csv
#   figures/key_parameters.png    posterior mean and 89% interval of the home
#                                 effect, back-to-back effect, and the spread
#                                 (SD) of team-specific home effects
#
# Usage (from the repository root):   Rscript R/04_figures.R
# Requires: ggplot2, dplyr, readr
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
})

dir.create("figures", showWarnings = FALSE)

# Fixed colour per model (same model, same colour in every figure).
model_levels <- c("M1  team home slopes",
                  "M3  team intercepts",
                  "M4  strength + home deviation",
                  "M7  exploratory (+ turnovers, FT%)")
model_cols <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100")
names(model_cols) <- model_levels

theme_set(
  theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.major.x = element_line(colour = "grey88"),
      plot.title    = element_text(face = "bold"),
      plot.subtitle = element_text(colour = "grey35"),
      legend.position = "none",
      strip.text = element_text(face = "bold")
    )
)

# --- WAIC comparison ----------------------------------------------------------
waic <- read_csv("results/waic_table.csv", show_col_types = FALSE) %>%
  mutate(label = case_when(
    startsWith(model, "Model 3") ~ model_levels[2],
    startsWith(model, "Model 4") ~ model_levels[3],
    startsWith(model, "Model 7") ~ model_levels[4],
    startsWith(model, "Model 1") ~ model_levels[1]
  ))

p_waic <- ggplot(waic, aes(x = WAIC, y = reorder(label, -WAIC), colour = label)) +
  geom_errorbarh(aes(xmin = WAIC - std_err, xmax = WAIC + std_err),
                 height = 0, linewidth = 0.8) +
  geom_point(size = 3.5) +
  geom_text(aes(label = sprintf("dWAIC = %.0f", dWAIC)),
            vjust = -1.3, size = 3.4, colour = "grey25") +
  scale_colour_manual(values = model_cols) +
  scale_x_continuous(expand = expansion(mult = 0.06)) +
  labs(
    title = "Model comparison with WAIC",
    subtitle = "Lower is better; bars show +/- 1 standard error of the WAIC estimate",
    x = "WAIC", y = NULL
  )
ggsave("figures/waic_comparison.png", p_waic, width = 8, height = 3.6, dpi = 200,
       bg = "white")

# --- Key parameters across models ---------------------------------------------
read_summary <- function(file, label) {
  read_csv(file, show_col_types = FALSE) %>%
    select(parameter, mean, lo = `5.5%`, hi = `94.5%`) %>%
    mutate(label = label)
}

pars <- bind_rows(
  read_summary("results/m1_summary.csv", model_levels[1]),
  read_summary("results/m3_summary.csv", model_levels[2]),
  read_summary("results/m4_summary.csv", model_levels[3]),
  read_summary("results/m7_summary.csv", model_levels[4])
)

# The "spread of team-specific home effects" is called sigma_u in M1/M7 and
# sigma_home in M4 (M3 has no team-specific home effects).
key <- pars %>%
  filter(parameter %in% c("b_home", "b_b2b", "sigma_u", "sigma_home")) %>%
  mutate(
    quantity = case_when(
      parameter == "b_home"                     ~ "League-wide home effect (log-odds)",
      parameter == "b_b2b"                      ~ "Back-to-back effect (log-odds)",
      parameter %in% c("sigma_u", "sigma_home") ~ "SD of team-specific home effects"
    ),
    quantity = factor(quantity, levels = c(
      "League-wide home effect (log-odds)",
      "Back-to-back effect (log-odds)",
      "SD of team-specific home effects")),
    label = factor(label, levels = rev(model_levels))
  )

p_key <- ggplot(key, aes(x = mean, y = label, colour = label)) +
  geom_vline(data = data.frame(quantity = factor(
               "Back-to-back effect (log-odds)", levels = levels(key$quantity)),
             x = 0), aes(xintercept = x), colour = "grey60", linetype = "dashed") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = 0.8) +
  geom_point(size = 3) +
  facet_wrap(~quantity, ncol = 1, scales = "free_x") +
  scale_x_continuous(expand = expansion(mult = 0.06)) +
  scale_colour_manual(values = model_cols) +
  labs(
    title = "Posterior summaries across models",
    subtitle = "Points: posterior mean. Bars: 89% interval (5.5% to 94.5%)",
    x = NULL, y = NULL
  )
ggsave("figures/key_parameters.png", p_key, width = 8, height = 7, dpi = 200,
       bg = "white")

message("Wrote figures/waic_comparison.png and figures/key_parameters.png")
