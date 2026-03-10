library(dplyr)
library(tidyr)

# run from project root: Rscript analysis/statistical_tests.R
BASE <- "/Users/luisbrunard/Documents/ULB/MA1/HEURISTICS/IMPL 1"
setwd(BASE)

# load results
df_raw <- read.csv("results/results_summary.csv", sep = ";", header = TRUE,
                   stringsAsFactors = FALSE)
colnames(df_raw) <- c("Instance", "Init", "NH", "Pivot",
                      "InitCost", "FinalCost", "Time")

# load best-known values
# the file has lines like: "N-be75eec_150 12345"
# some instance names have internal spaces so we join all tokens except the last
bk_lines <- readLines("code/best_known/best_known.txt")
bk_lines <- bk_lines[nchar(trimws(bk_lines)) > 0]
bk_parsed <- lapply(bk_lines, function(l) {
  parts <- strsplit(trimws(l), "\\s+")[[1]]
  parts <- parts[nchar(parts) > 0]
  if (length(parts) < 2) return(NULL)
  list(name  = trimws(paste(parts[-length(parts)], collapse="")),
       value = as.numeric(parts[length(parts)]))
})
bk_parsed <- Filter(Negate(is.null), bk_parsed)
bk_raw <- data.frame(
  InstanceBase = sapply(bk_parsed, `[[`, "name"),
  BestKnown    = sapply(bk_parsed, `[[`, "value"),
  stringsAsFactors = FALSE
)
bk_raw$InstanceBase <- gsub("\\s+", "", bk_raw$InstanceBase)

df_raw$InstanceBase <- gsub("\\s+", "", basename(df_raw$Instance))
df <- merge(df_raw, bk_raw, by = "InstanceBase", all.x = TRUE)
df$BestKnown <- as.numeric(df$BestKnown)

# RPD: positive = we beat the best-known (can happen when BK is approximate)
df$RPD <- (df$BestKnown - df$FinalCost) / df$BestKnown * 100

# algorithm labels
nh_labels   <- c("0"="Transpose", "1"="Exchange", "2"="Insert",
                 "3"="VND-TEI",   "4"="VND-TIE")
init_labels <- c("0"="Random", "1"="CW")
piv_labels  <- c("0"="First",  "1"="Best")

df$NH_Label    <- nh_labels[as.character(df$NH)]
df$Init_Label  <- init_labels[as.character(df$Init)]
df$Pivot_Label <- piv_labels[as.character(df$Pivot)]
df$Algorithm   <- ifelse(df$NH %in% c(3,4),
                         df$NH_Label,
                         paste0(df$NH_Label, "-", df$Pivot_Label))
df$Config <- paste0(df$Algorithm, " (", df$Init_Label, ")")

# summary statistics
cat("\nSUMMARY STATISTICS (RPD %)\n")
summary_tbl <- df %>%
  group_by(Config) %>%
  summarise(
    N         = n(),
    Mean_RPD  = round(mean(RPD,  na.rm=TRUE), 4),
    SD_RPD    = round(sd(RPD,    na.rm=TRUE), 4),
    Mean_Time = round(mean(Time, na.rm=TRUE), 4),
    .groups = "drop"
  ) %>%
  arrange(Mean_RPD)
print(as.data.frame(summary_tbl), row.names = FALSE)
write.csv(summary_tbl, "results/summary_statistics.csv", row.names = FALSE)

# ex 1.1: pairwise Wilcoxon tests between all 12 LS configurations
cat("\nEX 1.1 — PAIRWISE WILCOXON TESTS\n")

ls_configs <- df %>%
  filter(NH %in% c(0,1,2)) %>%
  pull(Config) %>% unique() %>% sort()

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
      ok <- complete.cases(x, y)
      if (sum(ok) < 5) next
      test <- wilcox.test(x[ok], y[ok], paired=TRUE, exact=FALSE, correct=TRUE)
      results <- rbind(results, data.frame(
        Algo1       = a1,
        Algo2       = a2,
        p.value     = round(test$p.value, 4),
        significant = ifelse(test$p.value < 0.05, "YES *", "no")
      ))
    }
  }
  results
}

wilcox_ls <- run_wilcoxon(ls_wide, ls_configs)
print(wilcox_ls, row.names = FALSE)
write.csv(wilcox_ls, "results/wilcoxon_ex1_1.csv", row.names = FALSE)

# ex 1.2: VND-TEI vs VND-TIE
cat("\nEX 1.2 — VND-TEI vs VND-TIE\n")

vnd_df <- df %>% filter(NH %in% c(3,4))

if (nrow(vnd_df) > 0) {
  vnd_wide <- vnd_df %>%
    select(InstanceBase, NH_Label, RPD) %>%
    pivot_wider(names_from = NH_Label, values_from = RPD)

  if (all(c("VND-TEI","VND-TIE") %in% colnames(vnd_wide))) {
    ok <- complete.cases(vnd_wide$`VND-TEI`, vnd_wide$`VND-TIE`)
    test_vnd <- wilcox.test(vnd_wide$`VND-TEI`[ok], vnd_wide$`VND-TIE`[ok],
                            paired=TRUE, exact=FALSE, correct=TRUE)
    cat(sprintf("W = %.1f, p = %.4f  ->  %s\n",
                test_vnd$statistic, test_vnd$p.value,
                ifelse(test_vnd$p.value < 0.05,
                       "SIGNIFICANT (p < 0.05)",
                       "no significant difference (p >= 0.05)")))
    write.csv(data.frame(Test        = "VND-TEI vs VND-TIE",
                         W           = test_vnd$statistic,
                         p.value     = round(test_vnd$p.value, 4),
                         significant = ifelse(test_vnd$p.value < 0.05, "YES *", "no")),
              "results/wilcoxon_ex1_2.csv", row.names=FALSE)
  } else {
    cat("VND columns not found.\n")
  }
} else {
  cat("No VND results in CSV.\n")
}

# export raw RPD data
raw_out <- df %>%
  select(Instance, Init_Label, NH_Label, Pivot_Label, FinalCost, BestKnown, RPD, Time) %>%
  arrange(NH_Label, Pivot_Label, Init_Label, Instance)
write.table(raw_out, "results/raw_data_for_report.txt",
            sep="\t", row.names=FALSE, quote=FALSE)

cat("\nDone.\n")
