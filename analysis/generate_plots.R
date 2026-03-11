library(ggplot2)
library(dplyr)
library(tidyr)

setwd("/Users/luisbrunard/Documents/ULB/MA1/HEURISTICS/IMPL 1")
OUT <- "report/plots"
dir.create(OUT, showWarnings = FALSE)

# load results and best-known
df_raw <- read.csv("results/results_summary.csv", sep = ";", header = TRUE,
                   stringsAsFactors = FALSE)
colnames(df_raw) <- c("Instance", "Init", "NH", "Pivot",
                      "InitCost", "FinalCost", "Time")

bk_lines  <- readLines("code/best_known/best_known.txt")
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

df$NH_Label    <- nh_labels[as.character(df$NH)]
df$Init_Label  <- init_labels[as.character(df$Init)]
df$Pivot_Label <- piv_labels[as.character(df$Pivot)]
df$Algorithm   <- ifelse(df$NH %in% c(3,4), df$NH_Label,
                         paste0(df$NH_Label, "-", df$Pivot_Label))
df$Config      <- paste0(df$Algorithm, " (", df$Init_Label, ")")

summary_df <- df %>%
  group_by(Config, Algorithm, NH_Label, Init_Label, Pivot_Label, NH) %>%
  summarise(Mean_RPD  = mean(RPD,  na.rm=TRUE),
            SD_RPD    = sd(RPD,    na.rm=TRUE),
            Mean_Time = mean(Time, na.rm=TRUE),
            .groups   = "drop")

nh_colours  <- c("Transpose"="#e74c3c", "Exchange"="#f39c12",
                 "Insert"   ="#27ae60", "VND-TEI"  ="#2980b9",
                 "VND-TIE"  ="#8e44ad")
init_shapes <- c("CW"=16, "Random"=17)

theme_clean <- theme_minimal(base_size = 12) +
  theme(plot.title    = element_blank(),
        plot.subtitle = element_blank())

# plot 1: avg RPD bar chart (Exchange, Insert, VND)
p1_data <- summary_df %>%
  filter(NH_Label %in% c("Insert","Exchange","VND-TEI","VND-TIE")) %>%
  mutate(Config = reorder(Config, -Mean_RPD))

p1 <- ggplot(p1_data, aes(x = Mean_RPD, y = Config, fill = NH_Label)) +
  geom_col(width = 0.65) +
  geom_errorbar(aes(xmin = Mean_RPD - SD_RPD, xmax = Mean_RPD + SD_RPD),
                width = 0.3, linewidth = 0.6, colour = "grey30",
                orientation = "y") +
  geom_text(aes(x = Mean_RPD + SD_RPD, label = sprintf("%.2f%%", Mean_RPD)),
            hjust = -0.25, size = 3.3, colour = "grey20") +
  scale_fill_manual(values = nh_colours, name = "Neighbourhood") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(x = "Average RPD (%)", y = NULL) +
  theme_clean

ggsave(file.path(OUT, "plot1_rpd_barchart.png"), p1,
       width = 8, height = 4.5, dpi = 150)
cat("Saved plot1_rpd_barchart.png\n")

# plot 2: quality vs time scatter
p2_data <- summary_df %>%
  filter(NH_Label %in% c("Insert","Exchange","VND-TEI","VND-TIE"))

p2 <- ggplot(p2_data, aes(x = Mean_Time, y = Mean_RPD,
                           colour = NH_Label, shape = Init_Label)) +
  geom_point(size = 4.5, stroke = 1.3) +
  geom_text(aes(label = paste0(Algorithm, " (", Init_Label, ")")),
            vjust = -0.8, hjust = 0.5, size = 2.8, show.legend = FALSE) +
  scale_colour_manual(values = nh_colours, name = "Neighbourhood") +
  scale_shape_manual(values = init_shapes, name = "Initialisation") +
  scale_x_continuous(labels = function(x) paste0(x, " s")) +
  labs(x = "Average time per instance (s)", y = "Average RPD (%)") +
  theme_clean +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(OUT, "plot2_quality_vs_time.png"), p2,
       width = 7.5, height = 5, dpi = 150)
cat("Saved plot2_quality_vs_time.png\n")

# plot 2b: quality vs time scatter (ALL configs including Transpose)
library(ggrepel)
p2b <- ggplot(summary_df, aes(x = Mean_Time, y = Mean_RPD,
                               colour = NH_Label, shape = Init_Label)) +
  geom_point(size = 4.5, stroke = 1.3) +
  geom_text_repel(aes(label = paste0(Algorithm, " (", Init_Label, ")")),
                  size = 2.6, show.legend = FALSE,
                  max.overlaps = 20, seed = 42,
                  box.padding = 0.5, point.padding = 0.3) +
  scale_colour_manual(values = nh_colours, name = "Neighbourhood") +
  scale_shape_manual(values = init_shapes, name = "Initialisation") +
  scale_x_continuous(labels = function(x) paste0(x, " s")) +
  labs(x = "Average time per instance (s)", y = "Average RPD (%)") +
  theme_clean +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(OUT, "plot2b_quality_vs_time_all.png"), p2b,
       width = 8, height = 5.5, dpi = 150)
cat("Saved plot2b_quality_vs_time_all.png\n")

# plot 3: CW vs Random initialisation comparison
p3_data <- df %>%
  filter(NH_Label %in% c("Insert","Exchange")) %>%
  mutate(Label = paste0(NH_Label, "-", Pivot_Label)) %>%
  group_by(Label, Init_Label) %>%
  summarise(Mean_RPD = mean(RPD, na.rm=TRUE),
            SD_RPD   = sd(RPD,   na.rm=TRUE),
            .groups  = "drop") %>%
  mutate(Label = factor(Label, levels = c("Insert-First","Insert-Best",
                                          "Exchange-First","Exchange-Best")))

p3 <- ggplot(p3_data, aes(x = Label, y = Mean_RPD, fill = Init_Label)) +
  geom_col(position = position_dodge(width = 0.65), width = 0.6) +
  geom_errorbar(aes(ymin = Mean_RPD - SD_RPD, ymax = Mean_RPD + SD_RPD),
                position = position_dodge(width = 0.65),
                width = 0.2, linewidth = 0.7, colour = "grey30") +
  scale_fill_manual(values = c("CW"="#3498db","Random"="#e74c3c"),
                    name = "Initialisation") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(x = NULL, y = "Average RPD (%)") +
  theme_clean +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave(file.path(OUT, "plot3_init_comparison.png"), p3,
       width = 7, height = 4.5, dpi = 150)
cat("Saved plot3_init_comparison.png\n")

# plot 4: VND-TEI vs VND-TIE
vnd_summary <- summary_df %>% filter(NH_Label %in% c("VND-TEI","VND-TIE"))

p4 <- ggplot(vnd_summary, aes(x = NH_Label, y = Mean_RPD, fill = NH_Label)) +
  geom_col(width = 0.5) +
  geom_errorbar(aes(ymin = Mean_RPD - SD_RPD, ymax = Mean_RPD + SD_RPD),
                width = 0.12, linewidth = 0.8, colour = "grey30") +
  geom_text(aes(y = Mean_RPD + SD_RPD, label = sprintf("%.2f%%", Mean_RPD)),
            vjust = -0.6, size = 4, colour = "grey20") +
  scale_fill_manual(values = c("VND-TEI"="#2980b9","VND-TIE"="#8e44ad"),
                    name = "VND ordering") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(x = NULL, y = "Average RPD (%)") +
  theme_clean

ggsave(file.path(OUT, "plot4_vnd_comparison.png"), p4,
       width = 4.5, height = 4, dpi = 150)
cat("Saved plot4_vnd_comparison.png\n")





# plot 6: execution time bar chart (all configs)
p6_data <- summary_df %>%
  mutate(Config = reorder(Config, Mean_Time))

p6 <- ggplot(p6_data, aes(x = Mean_Time, y = Config, fill = NH_Label)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = sprintf("%.3f s", Mean_Time)),
            hjust = -0.1, size = 3.3, colour = "grey20") +
  scale_fill_manual(values = nh_colours, name = "Neighbourhood") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.22)),
                     labels = function(x) paste0(x, " s")) +
  labs(x = "Average time per instance (s)", y = NULL) +
  theme_clean

ggsave(file.path(OUT, "plot6_time_barchart.png"), p6,
       width = 8, height = 5, dpi = 150)
cat("Saved plot6_time_barchart.png\n")

cat("Done.\n")

