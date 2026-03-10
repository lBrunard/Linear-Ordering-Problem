# ============================================================
# Plot generation for LOP report
# Outputs PNG files into ../plots/
# ============================================================
library(ggplot2)
library(dplyr)
library(tidyr)

setwd("/Users/luisbrunard/Documents/ULB/MA1/HEURISTICS/IMPL 1/heuristic_optimization_lop")
OUT <- "../plots"
dir.create(OUT, showWarnings = FALSE)

# ---- Load & prepare data (same as statistical_tests.R) -------------------
df_raw <- read.csv("results_summary.csv", sep = ";", header = TRUE,
                   stringsAsFactors = FALSE)
colnames(df_raw) <- c("Instance", "Init", "NH", "Pivot",
                      "InitCost", "FinalCost", "Time")

bk_lines  <- readLines("best_known/best_known.txt")
bk_lines  <- bk_lines[nchar(trimws(bk_lines)) > 0]
bk_parsed <- lapply(bk_lines, function(l) {
  p <- strsplit(trimws(l), "\\s+")[[1]]
  p <- p[nchar(p) > 0]
  if (length(p) < 2) return(NULL)
  list(name = trimws(paste(p[-length(p)], collapse="")), value = as.numeric(p[length(p)]))
})
bk_parsed <- Filter(Negate(is.null), bk_parsed)
bk_raw <- data.frame(
  InstanceBase = sapply(bk_parsed, `[[`, "name"),
  BestKnown    = sapply(bk_parsed, `[[`, "value"),
  stringsAsFactors = FALSE)
bk_raw$InstanceBase <- gsub("\\s+", "", bk_raw$InstanceBase)

df_raw$InstanceBase <- gsub("\\s+", "", basename(df_raw$Instance))
df <- merge(df_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
df$BestKnown <- as.numeric(df$BestKnown)
df$RPD <- (df$BestKnown - df$FinalCost) / df$BestKnown * 100

nh_labels   <- c("0"="Transpose","1"="Exchange","2"="Insert","3"="VND-TEI","4"="VND-TIE")
init_labels <- c("0"="Random","1"="CW")
piv_labels  <- c("0"="First","1"="Best")

df$NH_Label   <- nh_labels[as.character(df$NH)]
df$Init_Label <- init_labels[as.character(df$Init)]
df$Pivot_Label<- piv_labels[as.character(df$Pivot)]
df$Algorithm  <- ifelse(df$NH %in% c(3,4), df$NH_Label,
                        paste0(df$NH_Label, "-", df$Pivot_Label))
df$Config     <- paste0(df$Algorithm, "\n(", df$Init_Label, ")")

# summary per config
summary_df <- df %>%
  group_by(Config, Algorithm, NH_Label, Init_Label, Pivot_Label, NH) %>%
  summarise(Mean_RPD  = mean(RPD,  na.rm=TRUE),
            SD_RPD    = sd(RPD,    na.rm=TRUE),
            Mean_Time = mean(Time, na.rm=TRUE),
            .groups   = "drop")

# ---- Colour palette ---------------------------------------------------------
nh_colours <- c("Transpose"="#e74c3c", "Exchange"="#f39c12",
                "Insert"   ="#27ae60", "VND-TEI"  ="#2980b9",
                "VND-TIE"  ="#8e44ad")
init_shapes <- c("CW"=16, "Random"=17)

# ---- PLOT 1 : Horizontal bar — Avg RPD by configuration -------------------
p1_data <- summary_df %>%
  mutate(Config = reorder(Config, -Mean_RPD))

# Exclude transpose for a readable version (shown separately)
p1_main <- p1_data %>% filter(NH_Label %in% c("Insert","Exchange","VND-TEI","VND-TIE"))

p1 <- ggplot(p1_main, aes(x = Mean_RPD, y = Config, fill = NH_Label)) +
  geom_col(width = 0.7) +
  geom_errorbarh(aes(xmin = Mean_RPD - SD_RPD, xmax = Mean_RPD + SD_RPD),
                 height = 0.3, linewidth = 0.6, colour = "grey30") +
  geom_text(aes(label = sprintf("%.2f%%", Mean_RPD)),
            hjust = -0.2, size = 3.2, colour = "grey20") +
  scale_fill_manual(values = nh_colours, name = "Neighbourhood") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title   = "Solution quality by algorithm configuration",
       subtitle = "Average RPD (%) over 78 instances — lower is better\n(Transpose excluded: RPD 19–35%)",
       x = "Average RPD (%)", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right",
        plot.title    = element_text(face = "bold"),
        axis.text.y   = element_text(size = 9))

ggsave(file.path(OUT, "plot1_rpd_barchart.png"), p1,
       width = 8, height = 5, dpi = 150)
cat("Saved plot1_rpd_barchart.png\n")

# ---- PLOT 1b : All neighbourhoods including transpose ----------------------
p1b <- ggplot(p1_data, aes(x = Mean_RPD, y = Config, fill = NH_Label)) +
  geom_col(width = 0.7) +
  geom_errorbarh(aes(xmin = Mean_RPD - SD_RPD, xmax = Mean_RPD + SD_RPD),
                 height = 0.3, linewidth = 0.6, colour = "grey30") +
  geom_text(aes(label = sprintf("%.1f%%", Mean_RPD)),
            hjust = -0.15, size = 3, colour = "grey20") +
  scale_fill_manual(values = nh_colours, name = "Neighbourhood") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title   = "Solution quality — all configurations",
       subtitle = "Average RPD (%) over 78 instances — lower is better",
       x = "Average RPD (%)", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right",
        plot.title    = element_text(face = "bold"),
        axis.text.y   = element_text(size = 8.5))

ggsave(file.path(OUT, "plot1b_rpd_all.png"), p1b,
       width = 8, height = 6.5, dpi = 150)
cat("Saved plot1b_rpd_all.png\n")

# ---- PLOT 2 : Quality vs Time scatter (Pareto front view) ------------------
p2_data <- summary_df %>% filter(NH_Label %in% c("Insert","Exchange","VND-TEI","VND-TIE"))

p2 <- ggplot(p2_data, aes(x = Mean_Time, y = Mean_RPD,
                           colour = NH_Label, shape = Init_Label,
                           label = Algorithm)) +
  geom_point(size = 4, stroke = 1.2) +
  geom_text(aes(label = paste0(Algorithm, "\n(", Init_Label, ")")),
            vjust = -0.7, hjust = 0.5, size = 2.8) +
  scale_colour_manual(values = nh_colours, name = "Neighbourhood") +
  scale_shape_manual(values = init_shapes, name = "Init") +
  scale_x_continuous(labels = function(x) paste0(x, "s")) +
  labs(title   = "Quality vs. computation time",
       subtitle = "Each point = one algorithm configuration (avg over 78 instances)\nBottom-left corner is best",
       x = "Average time per instance (s)",
       y = "Average RPD (%) — lower is better") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "right")

ggsave(file.path(OUT, "plot2_quality_vs_time.png"), p2,
       width = 8, height = 5.5, dpi = 150)
cat("Saved plot2_quality_vs_time.png\n")

# ---- PLOT 3 : CW vs Random — RPD distribution (boxplot) -------------------
p3_data <- df %>%
  filter(NH_Label %in% c("Insert","Exchange")) %>%
  mutate(Label = paste0(NH_Label, "-", Pivot_Label))

p3 <- ggplot(p3_data, aes(x = Label, y = RPD, fill = Init_Label)) +
  geom_boxplot(outlier.size = 1.2, width = 0.55,
               position = position_dodge(width = 0.65)) +
  scale_fill_manual(values = c("CW"="#3498db","Random"="#e74c3c"),
                    name = "Initialisation") +
  labs(title   = "Impact of initialisation on solution quality",
       subtitle = "Distribution of RPD (%) — CW vs Random start",
       x = NULL, y = "RPD (%) — lower is better") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 15, hjust = 1))

ggsave(file.path(OUT, "plot3_init_comparison.png"), p3,
       width = 7.5, height = 5, dpi = 150)
cat("Saved plot3_init_comparison.png\n")

# ---- PLOT 4 : VND comparison -----------------------------------------------
vnd_data <- df %>% filter(NH_Label %in% c("VND-TEI","VND-TIE"))

p4 <- ggplot(vnd_data, aes(x = NH_Label, y = RPD, fill = NH_Label)) +
  geom_violin(trim = FALSE, alpha = 0.5, width = 0.8) +
  geom_boxplot(width = 0.2, outlier.size = 1.5, fill = "white") +
  scale_fill_manual(values = c("VND-TEI"="#2980b9","VND-TIE"="#8e44ad"),
                    name = "VND ordering") +
  labs(title   = "VND-TEI vs VND-TIE — RPD distribution",
       subtitle = "Wilcoxon signed-rank test: p = 0.0074 (significant)",
       x = NULL, y = "RPD (%) — lower is better") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "none")

ggsave(file.path(OUT, "plot4_vnd_comparison.png"), p4,
       width = 5, height = 4.5, dpi = 150)
cat("Saved plot4_vnd_comparison.png\n")

cat("All plots saved to", OUT, "\n")
