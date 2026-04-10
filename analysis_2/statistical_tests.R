library(dplyr)
library(tidyr)

# run from project root: Rscript analysis_2/statistical_tests.R

BASE <- "/Users/luisbrunard/Documents/ULB/MA1/HEURISTICS/IMPL 1"
setwd(BASE)

# ---- load SLS results ----
sls_raw <- read.csv("results_2/sls_results.csv", sep = ";", header = TRUE,
                    stringsAsFactors = FALSE)
colnames(sls_raw) <- c("Instance", "Init", "Algo", "Pivot",
                       "InitCost", "FinalCost", "Time")

# ---- load best-known values ----
bk_lines <- readLines("code/best_known/best_known.txt")
bk_lines <- bk_lines[nchar(trimws(bk_lines)) > 0]
bk_parsed <- lapply(bk_lines, function(l) {
  parts <- strsplit(trimws(l), "\\s+")[[1]]
  parts <- parts[nchar(parts) > 0]
  if (length(parts) < 2) return(NULL)
  list(name  = trimws(paste(parts[-length(parts)], collapse = "")),
       value = as.numeric(parts[length(parts)]))
})
bk_parsed <- Filter(Negate(is.null), bk_parsed)
bk_raw <- data.frame(
  InstanceBase = sapply(bk_parsed, `[[`, "name"),
  BestKnown    = sapply(bk_parsed, `[[`, "value"),
  stringsAsFactors = FALSE
)
bk_raw$InstanceBase <- gsub("\\s+", "", bk_raw$InstanceBase)

# ---- merge and compute RPD ----
sls_raw$InstanceBase <- gsub("\\s+", "", basename(sls_raw$Instance))
df <- merge(sls_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
df$BestKnown <- as.numeric(df$BestKnown)
df$RPD <- (df$BestKnown - df$FinalCost) / df$BestKnown * 100

# algorithm labels: Algo column: 1=SA, 2=ACO
algo_labels <- c("1" = "SA", "2" = "ACO")
df$AlgoLabel <- algo_labels[as.character(df$Algo)]

# ---- load VND results from exercise 1 (for comparison) ----
cat("\n====================================\n")
cat("  Loading VND results from Ex.1\n")
cat("====================================\n")

vnd_file <- "results/results_summary.csv"
if (file.exists(vnd_file)) {
  vnd_raw <- read.csv(vnd_file, sep = ";", header = TRUE,
                      stringsAsFactors = FALSE)
  colnames(vnd_raw) <- c("Instance", "Init", "NH", "Pivot",
                         "InitCost", "FinalCost", "Time")
  # VND-TIE = NH 4, keep only size 150
  vnd_tie <- vnd_raw %>%
    filter(NH == 4) %>%
    mutate(InstanceBase = gsub("\\s+", "", basename(Instance)))
  vnd_tie <- merge(vnd_tie, bk_raw, by = "InstanceBase", all.x = TRUE)
  vnd_tie$BestKnown <- as.numeric(vnd_tie$BestKnown)
  vnd_tie$RPD <- (vnd_tie$BestKnown - vnd_tie$FinalCost) / vnd_tie$BestKnown * 100
  # keep only 150 instances
  vnd_tie <- vnd_tie %>% filter(grepl("150", InstanceBase))
  vnd_tie$AlgoLabel <- "VND-TIE"
  has_vnd <- nrow(vnd_tie) > 0
  cat(sprintf("  Loaded %d VND-TIE results\n", nrow(vnd_tie)))
} else {
  has_vnd <- FALSE
  cat("  No Ex.1 results found (results/results_summary.csv)\n")
}

# ==============================================================
#  SUMMARY STATISTICS
# ==============================================================
cat("\n====================================\n")
cat("  SUMMARY STATISTICS (RPD %)\n")
cat("====================================\n")

summary_sls <- df %>%
  group_by(AlgoLabel) %>%
  summarise(
    N         = n(),
    Mean_RPD  = round(mean(RPD, na.rm = TRUE), 4),
    SD_RPD    = round(sd(RPD, na.rm = TRUE), 4),
    Min_RPD   = round(min(RPD, na.rm = TRUE), 4),
    Max_RPD   = round(max(RPD, na.rm = TRUE), 4),
    Mean_Time = round(mean(Time, na.rm = TRUE), 4),
    .groups   = "drop"
  ) %>%
  arrange(Mean_RPD)

if (has_vnd) {
  summary_vnd <- vnd_tie %>%
    summarise(
      AlgoLabel = "VND-TIE",
      N         = n(),
      Mean_RPD  = round(mean(RPD, na.rm = TRUE), 4),
      SD_RPD    = round(sd(RPD, na.rm = TRUE), 4),
      Min_RPD   = round(min(RPD, na.rm = TRUE), 4),
      Max_RPD   = round(max(RPD, na.rm = TRUE), 4),
      Mean_Time = round(mean(Time, na.rm = TRUE), 4)
    )
  summary_all <- bind_rows(summary_sls, summary_vnd) %>% arrange(Mean_RPD)
} else {
  summary_all <- summary_sls
}

print(as.data.frame(summary_all), row.names = FALSE)
write.csv(summary_all, "results_2/summary_statistics.csv", row.names = FALSE)

# ==============================================================
#  PER-INSTANCE RPD TABLE
# ==============================================================
cat("\n====================================\n")
cat("  PER-INSTANCE RPD\n")
cat("====================================\n")

per_instance <- df %>%
  select(InstanceBase, AlgoLabel, FinalCost, BestKnown, RPD, Time) %>%
  arrange(InstanceBase, AlgoLabel)

write.csv(per_instance, "results_2/per_instance_rpd.csv", row.names = FALSE)
cat(sprintf("  Saved %d rows to per_instance_rpd.csv\n", nrow(per_instance)))

# ==============================================================
#  WILCOXON SIGNED-RANK TESTS
# ==============================================================
cat("\n====================================\n")
cat("  WILCOXON SIGNED-RANK TESTS\n")
cat("====================================\n")

run_paired_wilcoxon <- function(df_wide, col_a, col_b) {
  if (!(col_a %in% colnames(df_wide)) || !(col_b %in% colnames(df_wide))) {
    return(data.frame(Algo1 = col_a, Algo2 = col_b,
                      W = NA, p.value = NA, significant = "N/A"))
  }
  x <- df_wide[[col_a]]
  y <- df_wide[[col_b]]
  ok <- complete.cases(x, y)
  if (sum(ok) < 5) {
    return(data.frame(Algo1 = col_a, Algo2 = col_b,
                      W = NA, p.value = NA, significant = "too few"))
  }
  test <- wilcox.test(x[ok], y[ok], paired = TRUE, exact = FALSE, correct = TRUE)
  data.frame(
    Algo1       = col_a,
    Algo2       = col_b,
    W           = round(test$statistic, 1),
    p.value     = round(test$p.value, 6),
    significant = ifelse(test$p.value < 0.05, "YES *", "no")
  )
}

# -- Test 1: SA vs ACO --
sls_wide <- df %>%
  select(InstanceBase, AlgoLabel, RPD) %>%
  pivot_wider(names_from = AlgoLabel, values_from = RPD)

results_wilcox <- run_paired_wilcoxon(sls_wide, "SA", "ACO")

# -- Tests 2 & 3: SA vs VND-TIE, ACO vs VND-TIE --
if (has_vnd) {
  vnd_rpd <- vnd_tie %>% select(InstanceBase, RPD) %>% rename(VND_TIE = RPD)
  all_wide <- sls_wide %>% left_join(vnd_rpd, by = "InstanceBase")
  colnames(all_wide)[colnames(all_wide) == "VND_TIE"] <- "VND-TIE"

  results_wilcox <- bind_rows(
    results_wilcox,
    run_paired_wilcoxon(all_wide, "SA", "VND-TIE"),
    run_paired_wilcoxon(all_wide, "ACO", "VND-TIE")
  )
}

print(as.data.frame(results_wilcox), row.names = FALSE)
write.csv(results_wilcox, "results_2/wilcoxon_tests.csv", row.names = FALSE)

# ==============================================================
#  RTD ANALYSIS
# ==============================================================
cat("\n====================================\n")
cat("  RTD ANALYSIS\n")
cat("====================================\n")

rtd_file <- "results_2/rtd_results.csv"
if (file.exists(rtd_file)) {
  rtd_raw <- read.csv(rtd_file, sep = ";", header = TRUE,
                      stringsAsFactors = FALSE)
  colnames(rtd_raw) <- c("Instance", "Algo", "Seed", "FinalCost", "Time")

  # merge with best-known
  rtd_raw$InstanceBase <- gsub("\\s+", "", rtd_raw$Instance)
  rtd <- merge(rtd_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
  rtd$BestKnown <- as.numeric(rtd$BestKnown)
  rtd$RPD <- (rtd$BestKnown - rtd$FinalCost) / rtd$BestKnown * 100

  # target qualities: 0.5%, 0.25%, 0.1% from best-known
  targets <- c(0.5, 0.25, 0.1)

  rtd_summary <- data.frame()
  for (tgt in targets) {
    tmp <- rtd %>%
      mutate(Reached = RPD <= tgt) %>%
      group_by(Instance, Algo) %>%
      summarise(
        Target      = tgt,
        SuccessRate = mean(Reached) * 100,
        MeanRPD     = round(mean(RPD), 4),
        MinRPD      = round(min(RPD), 4),
        MaxRPD      = round(max(RPD), 4),
        MeanTime    = round(mean(Time), 4),
        .groups     = "drop"
      )
    rtd_summary <- bind_rows(rtd_summary, tmp)
  }

  cat("\nRTD Success Rates:\n")
  print(as.data.frame(rtd_summary), row.names = FALSE)
  write.csv(rtd_summary, "results_2/rtd_summary.csv", row.names = FALSE)
  write.csv(rtd, "results_2/rtd_full.csv", row.names = FALSE)
  cat(sprintf("\n  Saved %d RTD runs to rtd_full.csv\n", nrow(rtd)))

} else {
  cat("  No RTD results found. Run auto_run.sh first.\n")
}

# ==============================================================
#  EXPORT RAW DATA
# ==============================================================
raw_out <- df %>%
  select(InstanceBase, AlgoLabel, FinalCost, BestKnown, RPD, Time) %>%
  arrange(AlgoLabel, InstanceBase)
write.table(raw_out, "results_2/raw_data_for_report.txt",
            sep = "\t", row.names = FALSE, quote = FALSE)

cat("\n====================================\n")
cat("  DONE\n")
cat("====================================\n")
cat("Output files in results_2/:\n")
cat("  - summary_statistics.csv\n")
cat("  - per_instance_rpd.csv\n")
cat("  - wilcoxon_tests.csv\n")
cat("  - rtd_summary.csv\n")
cat("  - rtd_full.csv\n")
cat("  - raw_data_for_report.txt\n")
