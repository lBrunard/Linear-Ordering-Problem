library(ggplot2)
library(dplyr)
library(tidyr)

# run from project root: Rscript analysis_2/generate_plots.R

BASE <- "/Users/luisbrunard/Documents/ULB/MA1/HEURISTICS/IMPL 1"
setwd(BASE)
OUT <- "report_2/plots"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# ---- load SLS results ----
sls_raw <- read.csv("results_2/sls_results.csv", sep = ";", header = TRUE,
                    stringsAsFactors = FALSE)
colnames(sls_raw) <- c("Instance", "Init", "Algo", "Pivot",
                       "InitCost", "FinalCost", "Time")

# ---- load best-known ----
bk_lines <- readLines("code/best_known/best_known.txt")
bk_lines <- bk_lines[nchar(trimws(bk_lines)) > 0]
bk_parsed <- lapply(bk_lines, function(l) {
  p <- strsplit(trimws(l), "\\s+")[[1]]
  p <- p[nchar(p) > 0]
  if (length(p) < 2) return(NULL)
  list(name = trimws(paste(p[-length(p)], collapse = "")),
       value = as.numeric(p[length(p)]))
})
bk_parsed <- Filter(Negate(is.null), bk_parsed)
bk_raw <- data.frame(
  InstanceBase = sapply(bk_parsed, `[[`, "name"),
  BestKnown    = sapply(bk_parsed, `[[`, "value"),
  stringsAsFactors = FALSE
)
bk_raw$InstanceBase <- gsub("\\s+", "", bk_raw$InstanceBase)

sls_raw$InstanceBase <- gsub("\\s+", "", basename(sls_raw$Instance))
df <- merge(sls_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
df$BestKnown <- as.numeric(df$BestKnown)
df$RPD <- (df$BestKnown - df$FinalCost) / df$BestKnown * 100

algo_labels <- c("1" = "SA", "2" = "ACO")
df$AlgoLabel <- algo_labels[as.character(df$Algo)]

# ---- load VND-TIE from Ex.1 for comparison ----
vnd_file <- "results/results_summary.csv"
has_vnd <- FALSE
if (file.exists(vnd_file)) {
  vnd_raw <- read.csv(vnd_file, sep = ";", header = TRUE,
                      stringsAsFactors = FALSE)
  colnames(vnd_raw) <- c("Instance", "Init", "NH", "Pivot",
                         "InitCost", "FinalCost", "Time")
  vnd_tie <- vnd_raw %>%
    filter(NH == 4) %>%
    mutate(InstanceBase = gsub("\\s+", "", basename(Instance)))
  vnd_tie <- merge(vnd_tie, bk_raw, by = "InstanceBase", all.x = TRUE)
  vnd_tie$BestKnown <- as.numeric(vnd_tie$BestKnown)
  vnd_tie$RPD <- (vnd_tie$BestKnown - vnd_tie$FinalCost) / vnd_tie$BestKnown * 100
  vnd_tie <- vnd_tie %>% filter(grepl("150", InstanceBase))
  vnd_tie$AlgoLabel <- "VND-TIE"
  has_vnd <- nrow(vnd_tie) > 0
}

# colours
algo_colours <- c("SA" = "#e74c3c", "ACO" = "#2980b9", "VND-TIE" = "#27ae60")

theme_clean <- theme_minimal(base_size = 12) +
  theme(plot.title = element_blank(), plot.subtitle = element_blank())


# ==============================================================
#  PLOT 1 — RPD bar chart: SA vs ACO (+ VND-TIE if available)
# ==============================================================

summary_df <- df %>%
  group_by(AlgoLabel) %>%
  summarise(Mean_RPD  = mean(RPD, na.rm = TRUE),
            SD_RPD    = sd(RPD, na.rm = TRUE),
            Mean_Time = mean(Time, na.rm = TRUE),
            .groups   = "drop")

if (has_vnd) {
  vnd_summary <- vnd_tie %>%
    summarise(AlgoLabel = "VND-TIE",
              Mean_RPD  = mean(RPD, na.rm = TRUE),
              SD_RPD    = sd(RPD, na.rm = TRUE),
              Mean_Time = mean(Time, na.rm = TRUE))
  summary_df <- bind_rows(summary_df, vnd_summary)
}

summary_df <- summary_df %>% mutate(AlgoLabel = reorder(AlgoLabel, -Mean_RPD))

p1 <- ggplot(summary_df, aes(x = Mean_RPD, y = AlgoLabel, fill = AlgoLabel)) +
  geom_col(width = 0.55) +
  geom_errorbar(aes(xmin = Mean_RPD - SD_RPD, xmax = Mean_RPD + SD_RPD),
                width = 0.2, linewidth = 0.6, colour = "grey30",
                orientation = "y") +
  geom_text(aes(x = Mean_RPD + SD_RPD, label = sprintf("%.2f%%", Mean_RPD)),
            hjust = -0.25, size = 3.5, colour = "grey20") +
  scale_fill_manual(values = algo_colours, name = "Algorithm") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.2))) +
  labs(x = "Average RPD (%)", y = NULL) +
  theme_clean

ggsave(file.path(OUT, "plot1_rpd_comparison.png"), p1,
       width = 7, height = 3.5, dpi = 150)
cat("Saved plot1_rpd_comparison.png\n")


# ==============================================================
#  PLOT 2 — Correlation plot: SA RPD vs ACO RPD per instance
# ==============================================================

corr_wide <- df %>%
  select(InstanceBase, AlgoLabel, RPD) %>%
  pivot_wider(names_from = AlgoLabel, values_from = RPD)

if (all(c("SA", "ACO") %in% colnames(corr_wide))) {
  max_val <- max(c(corr_wide$SA, corr_wide$ACO), na.rm = TRUE) * 1.05

  p2 <- ggplot(corr_wide, aes(x = SA, y = ACO)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                colour = "grey50", linewidth = 0.6) +
    geom_point(size = 2.5, colour = "#2c3e50", alpha = 0.7) +
    coord_fixed(xlim = c(0, max_val), ylim = c(0, max_val)) +
    labs(x = "SA — RPD (%)", y = "ACO — RPD (%)") +
    annotate("text", x = max_val * 0.95, y = max_val * 0.05,
             label = "Below line = ACO better",
             hjust = 1, size = 3, colour = "grey40") +
    annotate("text", x = (max_val * 0.025), y = max_val * 0.95,
             label = "Above line = SA better",
             hjust = 0, size = 3, colour = "grey40") +
    theme_clean

  ggsave(file.path(OUT, "plot2_correlation.png"), p2,
         width = 6, height = 6, dpi = 150)
  cat("Saved plot2_correlation.png\n")
}


# ==============================================================
#  PLOT 3 — Box plot: RPD distribution per algorithm
# ==============================================================

if (has_vnd) {
  box_data <- bind_rows(
    df %>% select(InstanceBase, AlgoLabel, RPD),
    vnd_tie %>% select(InstanceBase, AlgoLabel, RPD)
  )
} else {
  box_data <- df %>% select(InstanceBase, AlgoLabel, RPD)
}

p3 <- ggplot(box_data, aes(x = AlgoLabel, y = RPD, fill = AlgoLabel)) +
  geom_boxplot(width = 0.5, outlier.size = 1.5) +
  scale_fill_manual(values = algo_colours, name = "Algorithm") +
  labs(x = NULL, y = "RPD (%)") +
  theme_clean

ggsave(file.path(OUT, "plot3_boxplot.png"), p3,
       width = 5.5, height = 4.5, dpi = 150)
cat("Saved plot3_boxplot.png\n")


# ==============================================================
#  PLOT 4 — RTD: box plot of final RPD across 25 seeds
# ==============================================================

rtd_file <- "results_2/rtd_results.csv"
if (file.exists(rtd_file)) {
  rtd_raw <- read.csv(rtd_file, sep = ";", header = TRUE,
                      stringsAsFactors = FALSE)
  colnames(rtd_raw) <- c("Instance", "Algo", "Seed", "FinalCost", "Time")

  rtd_raw$InstanceBase <- gsub("\\s+", "", rtd_raw$Instance)
  rtd <- merge(rtd_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
  rtd$BestKnown <- as.numeric(rtd$BestKnown)
  rtd$RPD <- (rtd$BestKnown - rtd$FinalCost) / rtd$BestKnown * 100

  # Nice instance labels
  rtd$InstanceShort <- gsub("N-", "", rtd$InstanceBase)

  p4 <- ggplot(rtd, aes(x = Algo, y = RPD, fill = Algo)) +
    geom_boxplot(width = 0.5, outlier.size = 1.5) +
    geom_jitter(width = 0.15, size = 1, alpha = 0.4, colour = "grey30") +
    facet_wrap(~ InstanceBase, ncol = 2) +
    scale_fill_manual(values = algo_colours, name = "Algorithm") +
    geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50",
               linewidth = 0.5) +
    annotate("text", x = 2.4, y = 0.52, label = "0.5% target",
             size = 2.8, colour = "grey40", hjust = 1) +
    labs(x = NULL, y = "RPD (%)") +
    theme_clean +
    theme(strip.text = element_text(size = 10, face = "italic"))

  ggsave(file.path(OUT, "plot4_rtd_boxplot.png"), p4,
         width = 8, height = 4.5, dpi = 150)
  cat("Saved plot4_rtd_boxplot.png\n")


  # ==============================================================
  #  PLOT 5 — RTD: success rate bar chart at multiple thresholds
  # ==============================================================

  targets <- c(0.5, 0.25, 0.1)
  success_data <- data.frame()

  for (tgt in targets) {
    tmp <- rtd %>%
      group_by(InstanceBase, Algo) %>%
      summarise(
        Target = sprintf("RPD <= %.2f%%", tgt),
        SuccessRate = mean(RPD <= tgt) * 100,
        .groups = "drop"
      )
    success_data <- bind_rows(success_data, tmp)
  }

  success_data$Target <- factor(success_data$Target,
    levels = c("RPD <= 0.50%", "RPD <= 0.25%", "RPD <= 0.10%"))

  p5 <- ggplot(success_data,
               aes(x = Target, y = SuccessRate, fill = Algo)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6) +
    geom_text(aes(label = ifelse(SuccessRate > 0,
                                 sprintf("%.0f%%", SuccessRate), "")),
              position = position_dodge(width = 0.7),
              vjust = -0.4, size = 3) +
    facet_wrap(~ InstanceBase, ncol = 2) +
    scale_fill_manual(values = algo_colours, name = "Algorithm") +
    scale_y_continuous(limits = c(0, 105),
                       labels = function(x) paste0(x, "%")) +
    labs(x = "Quality target", y = "Success rate (out of 25 runs)") +
    theme_clean +
    theme(strip.text = element_text(size = 10, face = "italic"))

  ggsave(file.path(OUT, "plot5_rtd_success_rates.png"), p5,
         width = 9, height = 4.5, dpi = 150)
  cat("Saved plot5_rtd_success_rates.png\n")

} else {
  cat("No RTD results found. Skipping RTD plots.\n")
}


# ==============================================================
#  PLOT 7 — Per-instance RPD comparison (line plot)
# ==============================================================

inst_order <- df %>%
  filter(AlgoLabel == "SA") %>%
  arrange(RPD) %>%
  pull(InstanceBase)

df_ordered <- df %>%
  mutate(InstanceBase = factor(InstanceBase, levels = inst_order))

p7 <- ggplot(df_ordered, aes(x = InstanceBase, y = RPD,
                              colour = AlgoLabel, group = AlgoLabel)) +
  geom_line(linewidth = 0.5, alpha = 0.6) +
  geom_point(size = 1.5) +
  scale_colour_manual(values = algo_colours, name = "Algorithm") +
  labs(x = "Instance (sorted by SA RPD)", y = "RPD (%)") +
  theme_clean +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6))

ggsave(file.path(OUT, "plot7_per_instance.png"), p7,
       width = 12, height = 5, dpi = 150)
cat("Saved plot7_per_instance.png\n")


cat("\nAll plots saved to report_2/plots/\n")
