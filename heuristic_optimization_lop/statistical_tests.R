# ============================================================
# Statistical analysis — LOP Implementation Exercise 1
# Tests: Wilcoxon signed-rank (paired, non-parametric)
# ============================================================

library(dplyr)
library(tidyr)

# ---- 1. Load data -----------------------------------------------------------
df_raw <- read.csv("results_summary.csv", sep = ";", header = TRUE,
                   stringsAsFactors = FALSE)
colnames(df_raw) <- c("Instance", "Init", "NH", "Pivot",
                      "InitCost", "FinalCost", "Time")

# ---- 2. Load best-known solutions ------------------------------------------
bk_lines <- readLines("best_known/best_known.txt")
bk_lines <- bk_lines[nchar(trimws(bk_lines)) > 0]
bk_parsed <- lapply(bk_lines, function(l) {
  parts <- strsplit(trimws(l), "\\s+")[[1]]
  # remove empty strings
  parts <- parts[nchar(parts) > 0]
  if (length(parts) < 2) return(NULL)
  # instance name may contain internal spaces (e.g. "N- be75eec_250") — join all but last
  list(name = trimws(paste(parts[-length(parts)], collapse="")),
       value = as.numeric(parts[length(parts)]))
})
bk_parsed <- Filter(Negate(is.null), bk_parsed)
bk_raw <- data.frame(
  InstanceBase = sapply(bk_parsed, `[[`, "name"),
  BestKnown    = sapply(bk_parsed, `[[`, "value"),
  stringsAsFactors = FALSE
)
# Normalise: remove all spaces inside names
bk_raw$InstanceBase <- gsub("\\s+", "", bk_raw$InstanceBase)

# Extract base name from full path (e.g. "instances/N-foo_150" -> "N-foo_150")
df_raw$InstanceBase <- gsub("\\s+", "", basename(df_raw$Instance))

df <- merge(df_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
df$BestKnown <- as.numeric(df$BestKnown)

# ---- 3. Compute RPD ---------------------------------------------------------
# RPD = (BestKnown - FinalCost) / BestKnown * 100   (lower = better,
#        positive means we are below BK which can happen for approx BK)
df$RPD <- (df$BestKnown - df$FinalCost) / df$BestKnown * 100

# ---- 4. Build algorithm labels ----------------------------------------------
# NH codes: 0=Transpose,1=Exchange,2=Insert,3=VND-TEI,4=VND-TIE
# Pivot codes: 0=First,1=Best
nh_labels   <- c("0"="Transpose","1"="Exchange","2"="Insert",
                 "3"="VND-TEI",  "4"="VND-TIE")
init_labels <- c("0"="Random","1"="CW")
piv_labels  <- c("0"="First","1"="Best")

df$NH_Label   <- nh_labels[as.character(df$NH)]
df$Init_Label <- init_labels[as.character(df$Init)]
df$Pivot_Label<- piv_labels[as.character(df$Pivot)]

df$Algorithm <- ifelse(df$NH %in% c(3,4),
                       df$NH_Label,
                       paste0(df$NH_Label, "-", df$Pivot_Label))
df$Config <- paste0(df$Algorithm, " (", df$Init_Label, ")")

# ---- 5. Summary statistics --------------------------------------------------
cat("\n========== SUMMARY STATISTICS (RPD %) ==========\n")
summary_tbl <- df %>%
  group_by(Config) %>%
  summarise(
    N        = n(),
    Mean_RPD = round(mean(RPD, na.rm=TRUE), 4),
    SD_RPD   = round(sd(RPD,   na.rm=TRUE), 4),
    Mean_Time= round(mean(Time, na.rm=TRUE), 4),
    .groups = "drop"
  ) %>%
  arrange(Mean_RPD)
print(as.data.frame(summary_tbl), row.names = FALSE)

write.csv(summary_tbl, "summary_statistics.csv", row.names = FALSE)
cat("  -> saved to summary_statistics.csv\n")

# ---- 6. Exercise 1.1 — Wilcoxon tests (all 12 LS algorithms) ---------------
cat("\n========== EX 1.1 — PAIRWISE WILCOXON TESTS (RPD) ==========\n")

ls_configs <- df %>%
  filter(NH %in% c(0,1,2)) %>%
  pull(Config) %>%
  unique() %>%
  sort()

# Build wide table: one column per algorithm, one row per instance
ls_wide <- df %>%
  filter(NH %in% c(0,1,2)) %>%
  select(InstanceBase, Config, RPD) %>%
  pivot_wider(names_from = Config, values_from = RPD)

run_wilcoxon <- function(wide, configs) {
  n <- length(configs)
  results <- data.frame(Algo1=character(), Algo2=character(),
                        p.value=numeric(), significant=character(),
                        stringsAsFactors=FALSE)
  for (i in 1:(n-1)) {
    for (j in (i+1):n) {
      a1 <- configs[i]; a2 <- configs[j]
      if (!(a1 %in% colnames(wide)) || !(a2 %in% colnames(wide))) next
      x <- wide[[a1]]; y <- wide[[a2]]
      complete <- complete.cases(x, y)
      if (sum(complete) < 5) next
      test <- wilcox.test(x[complete], y[complete], paired=TRUE,
                          exact=FALSE, correct=TRUE)
      sig <- ifelse(test$p.value < 0.05, "YES *", "no")
      results <- rbind(results, data.frame(Algo1=a1, Algo2=a2,
                                           p.value=round(test$p.value,4),
                                           significant=sig))
    }
  }
  results
}

wilcox_ls <- run_wilcoxon(ls_wide, ls_configs)
print(wilcox_ls, row.names = FALSE)
write.csv(wilcox_ls, "wilcoxon_ex1_1.csv", row.names = FALSE)
cat("  -> saved to wilcoxon_ex1_1.csv\n")

# ---- 7. Exercise 1.2 — Wilcoxon test VND-TEI vs VND-TIE -------------------
cat("\n========== EX 1.2 — WILCOXON TEST VND-TEI vs VND-TIE ==========\n")

vnd_df <- df %>% filter(NH %in% c(3,4))

if (nrow(vnd_df) > 0) {
  vnd_wide <- vnd_df %>%
    select(InstanceBase, NH_Label, RPD) %>%
    pivot_wider(names_from = NH_Label, values_from = RPD)

  if (all(c("VND-TEI","VND-TIE") %in% colnames(vnd_wide))) {
    complete <- complete.cases(vnd_wide$`VND-TEI`, vnd_wide$`VND-TIE`)
    test_vnd <- wilcox.test(vnd_wide$`VND-TEI`[complete],
                            vnd_wide$`VND-TIE`[complete],
                            paired=TRUE, exact=FALSE, correct=TRUE)
    cat(sprintf("VND-TEI vs VND-TIE: W = %.1f, p = %.4f  ->  %s\n",
                test_vnd$statistic, test_vnd$p.value,
                ifelse(test_vnd$p.value < 0.05,
                       "SIGNIFICANT difference (p < 0.05)",
                       "No significant difference (p >= 0.05)")))
    write.csv(data.frame(Test="VND-TEI vs VND-TIE",
                         W=test_vnd$statistic,
                         p.value=round(test_vnd$p.value,4),
                         significant=ifelse(test_vnd$p.value<0.05,"YES *","no")),
              "wilcoxon_ex1_2.csv", row.names=FALSE)
    cat("  -> saved to wilcoxon_ex1_2.csv\n")
  } else {
    cat("  VND columns not found in data.\n")
  }
} else {
  cat("  No VND results found in CSV.\n")
}

# ---- 8. Export raw RPD data for submission (.txt) --------------------------
cat("\n========== EXPORTING RAW DATA ==========\n")
raw_out <- df %>%
  select(Instance, Init_Label, NH_Label, Pivot_Label, FinalCost, BestKnown, RPD, Time) %>%
  arrange(NH_Label, Pivot_Label, Init_Label, Instance)

write.table(raw_out, "raw_data_for_report.txt",
            sep="\t", row.names=FALSE, quote=FALSE)
cat("  -> saved to raw_data_for_report.txt\n")

cat("\nDone.\n")
