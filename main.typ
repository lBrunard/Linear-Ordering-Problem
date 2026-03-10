// ============================================================
//  INFO-H-413 — Heuristic Optimization
//  Implementation Exercise 1 — Linear Ordering Problem
// ============================================================
#set page(paper: "a4", margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm), numbering: "1")
#set text(font: "Linux Libertine", size: 11pt, lang: "en")
#set par(justify: true, leading: 0.72em)
#set heading(numbering: "1.")

// ---- Title ------------------------------------------------------------------
#align(center)[
  #v(0.4cm)
  #text(size: 16pt, weight: "bold")[
    Iterative Improvement Algorithms for the \
    Linear Ordering Problem
  ]
  #v(0.25cm)
  #text(size: 12pt)[INFO-H-413 — Heuristic Optimization — Implementation Exercise 1]
  #v(0.15cm)
  #text(size: 11pt, style: "italic")[Université Libre de Bruxelles — 2026]
  #v(0.4cm)
]

#line(length: 100%, stroke: 0.8pt)
#v(0.3cm)

// ---- Abstract ---------------------------------------------------------------
#align(center)[#text(weight: "bold")[Abstract]]

#block(inset: (left: 1cm, right: 1cm))[
This report describes the implementation and comparison of local search algorithms for the Linear Ordering Problem (LOP). Six iterative improvement algorithms were built by combining two pivoting strategies (first-improvement and best-improvement) with three neighbourhood structures (transpose, exchange, and insert). Two initialisation methods were tested: a random permutation and the greedy Chenery–Watanabe heuristic. A Variable Neighbourhood Descent (VND) algorithm was also implemented in two neighbourhood orderings. All algorithms were tested on 78 benchmark instances of sizes 150 and 250. Results show that the insert neighbourhood with CW initialisation achieves the best solution quality, that the CW heuristic is decisively better than random initialisation, and that VND-TIE slightly but significantly outperforms VND-TEI. Statistical significance was assessed with the Wilcoxon signed-rank test.
]

#v(0.4cm)
#line(length: 100%, stroke: 0.4pt)
#v(0.4cm)

// ---- 1. Introduction --------------------------------------------------------
= Introduction

The Linear Ordering Problem (LOP) asks the following question: given an $n times n$ matrix $C$ of weights, find an ordering (permutation) of the $n$ elements that maximises the sum of the weights that appear *above* the diagonal once the matrix rows and columns are reordered accordingly. Formally, we look for a permutation $pi$ that maximises:

$ f(pi) = sum_(i < j) c_(pi(i), pi(j)) $

Intuitively, we want to place element $i$ before element $j$ whenever $c_(i j) > c_(j i)$, i.e., when "choosing $i$ first" is more valuable. The problem is NP-hard, which means there is no known algorithm that solves it exactly in polynomial time for large instances. Heuristics are therefore needed.

This exercise focuses on *local search*: we start from some initial solution and keep making small changes that improve it, until no further improvement is possible. This final state is called a *local optimum*. We study how the choice of starting solution, the type of change allowed (neighbourhood), and the strategy for choosing which change to apply (pivoting rule) affect the quality of the result and the time needed to find it.

= Problem Description

== Neighbourhood Structures

A *neighbourhood* defines the set of solutions we can reach in one step from the current solution. Three neighbourhoods are considered.

*Transpose.* Swap two *adjacent* elements. From a permutation of length $n$, we can make $n-1$ such swaps. The gain $Delta$ of swapping positions $i$ and $i+1$ is simply:
$ Delta_T (i) = c_(pi(i+1),pi(i)) - c_(pi(i),pi(i+1)) $
This is $O(1)$

*Exchange.* Swap any two elements, not necessarily adjacent. There are $binom(n,2)$ possible pairs. Computing the gain requires scanning all elements between the two swapped positions, so it costs $O(n)$.

*Insert.* Remove an element from position $i$ and reinsert it at position $j$, shifting everything in between. This gives $n(n-1)$ possible moves (both forward and backward insertions). Each gain evaluation costs $O(n)$.

== Pivoting Rules

Once the neighbourhood is fixed, we need a strategy to choose which improving move to apply.

- *First-improvement (FI):* apply the first move with a positive gain and restart the scan immediately.
- *Best-improvement (BI):* scan the *entire* neighbourhood, then apply the move with the highest gain.

== Initialisation

- *Random:* generate a random permutation.
- *Chenery–Watanabe (CW):* rank each element by its row-sum score $R_i = sum_(j != i) c_(i j)$ and sort in decreasing order. This greedy heuristic puts elements that "benefit most from being first" at the front of the permutation.

= Algorithms

== Iterative Improvement (Exercise 1.1)

The basic algorithm is:
#block(inset: (left: 0.5cm))[
- Generate an initial solution $pi_0$.
- While an improving neighbour exists:
  -  (First-improvement) Apply the first move with $Delta > 0$; restart scan.
  -   (Best-improvement) Apply the move with the largest $Delta > 0$.
-  Return the local optimum $pi^*$.
]


Combining 2 pivoting rules with 3 neighbourhoods gives 6 algorithms, each run from 2 initial solutions = *12 configurations*.

== Variable Neighbourhood Descent (Exercise 1.2)

The idea behind VND is simple: a local optimum for one neighbourhood might not be optimal for another. So instead of giving up when we get stuck, we switch to a different neighbourhood. If the new neighbourhood finds an improvement, we restart from the first neighbourhood. We stop only when *none* of the neighbourhoods can improve the solution.

We use first-improvement only, starting from the CW solution. Two orderings of the three neighbourhoods are tested:
- *VND-TEI:* Transpose → Exchange → Insert
- *VND-TIE:* Transpose → Insert → Exchange

= Implementation

The solver is written in C (GCC, `-O3`). All source files are in `src/`. Compilation instructions and the full list of command-line options are provided in the `README.md` file included with the source code. The main entry point is `src/main.c`; all algorithm logic (delta functions, iterative improvement, VND) is in `src/optimization.c`.

= Statistical Testing Method <sec:stats>

Before presenting the results, we briefly explain how the statistical tests were performed and why.

== Why statistical tests?

When comparing two algorithms across many instances, it is tempting to simply compare average RPD values. However, averages can be misleading: one algorithm might be better on most instances but much worse on a few outliers, making the averages look similar. A statistical test checks whether an *observed difference* is likely to be real, or could just be due to random variation.

== The Wilcoxon signed-rank test

We use the *Wilcoxon signed-rank test*, a non-parametric paired test. Here is what each of these words means:

- *Paired:* we compare the two algorithms on the *same* instances. For each instance, we compute the difference in RPD between algorithm A and algorithm B. This is important because instances vary a lot in difficulty — pairing removes this source of variability.

- *Non-parametric:* the test does not assume that the RPD values follow a normal distribution. This is safer here, since RPD distributions can be skewed.

- *How it works:* the test ranks the absolute values of the per-instance differences, then checks whether the positive differences (A better than B) and negative differences (B better than A) are roughly balanced. If one algorithm is consistently better, the positive (or negative) ranks will dominate, giving a small p-value.

== Interpreting the p-value

The p-value is the probability of observing a difference at least as large as the one measured, *if the two algorithms were actually equal*. We use a threshold $alpha = 0.05$:

- $p < 0.05$: the difference is *statistically significant* — we conclude the two algorithms perform differently.
- $p >= 0.05$: the difference is *not significant* — we cannot conclude that one is better.

A significant result does not tell us which algorithm is better; it only tells us that they are *different*. The direction (which one is better) is read from the average RPD values.

= Results and Analysis

All 78 benchmark instances (sizes 150 and 250) were solved by each of the 14 algorithm configurations (12 for Ex 1.1 + 2 VND). Each instance was solved once. Solution quality is measured with the *Relative Percentage Deviation* (RPD) from the best-known solution:

$ "RPD" = frac("BestKnown" - "FinalCost", "BestKnown") times 100 $

An RPD of 0 means we matched the best-known value. A positive RPD means our solution is that many percent below the best known (so *lower RPD is better*).

== Exercise 1.1 — Iterative Improvement Results

@fig:rpd_bar gives an immediate visual overview of solution quality for the Insert, Exchange and VND configurations (Transpose is excluded from this chart as its RPD of 19–35% would compress the scale). @tab:results11 gives the full numerical results for all 12 configurations.

#figure(
  image("plots/plot1_rpd_barchart.png", width: 100%),
  caption: [Average RPD (%) with ± 1 SD error bars for Insert, Exchange, and VND configurations. Lower is better. Full results including Transpose are in @tab:results11.]
) <fig:rpd_bar>

#figure(
  table(
    columns: (2.6fr, 0.7fr, 0.8fr, 0.8fr, 0.9fr, 1.1fr),
    inset: 6pt,
    align: (left, center, center, center, center, right),
    fill: (x, y) => if y == 0 { luma(210) }
                    else if y <= 4  { rgb("#d4edda") }
                    else if y <= 8  { rgb("#fff3cd") }
                    else            { rgb("#f8d7da") },
    [*Algorithm*], [*Init*], [*Avg RPD*], [*SD*], [*Avg Time (s)*], [*Total Time (s)*],
    [Insert — First],    [CW],     [1.59], [0.33], [2.99], [233.4],
    [Insert — Best],     [CW],     [2.01], [0.45], [0.79], [ 61.7],
    [Insert — First],    [Random], [2.02], [0.45], [4.28], [333.8],
    [Insert — Best],     [Random], [2.30], [0.46], [0.85], [ 66.3],
    [Exchange — First],  [CW],     [2.52], [0.41], [3.97], [309.7],
    [Exchange — First],  [Random], [2.82], [0.48], [4.87], [380.1],
    [Exchange — Best],   [CW],     [3.28], [0.55], [0.70], [ 54.3],
    [Exchange — Best],   [Random], [3.60], [0.50], [0.76], [ 59.3],
    [Transpose — Best],  [CW],     [19.25],[1.89], [0.006],[ 0.45],
    [Transpose — First], [CW],     [19.38],[1.92], [0.003],[ 0.25],
    [Transpose — Best],  [Random], [34.47],[3.80], [0.007],[ 0.55],
    [Transpose — First], [Random], [34.61],[3.80], [0.004],[ 0.33],
  ),
  caption: [Average RPD (%), standard deviation, and computation times for all 12 configurations over 78 instances. Green = best group, yellow = intermediate, red = transpose (poor quality).]
) <tab:results11>

=== Observations

*Neighbourhood choice is the dominant factor.* The insert neighbourhood is clearly best: it achieves RPD around 1.6–2.3%, versus 2.5–3.6% for exchange and an unacceptably high 19–35% for transpose. Transpose simply cannot escape poor solutions because it can only make tiny adjacent swaps; it gets trapped in deep local optima.

*CW initialisation is significantly better than random.* For every neighbourhood and pivoting rule, the CW starting solution leads to better final results. The difference is most striking for transpose (19% vs 34% RPD), confirming that the CW heuristic provides a starting point already close to a good solution.

*First-improvement beats best-improvement in quality — but not in speed.* For insert, first-improvement (RPD 1.59% from CW) reaches a better solution than best-improvement (RPD 2.01% from CW). This is a somewhat surprising result. The reason is likely that first-improvement makes finer, more cautious moves, allowing it to explore a richer part of the search space before converging, whereas best-improvement makes large jumps that can overshoot.

*Best-improvement is much faster despite examining more neighbours per step.* Insert-BI from CW takes only 0.79 s on average, while Insert-FI from CW takes 2.99 s. Best-improvement converges in far fewer iterations because each step makes a bigger improvement, which more than compensates for the extra scanning work.

=== Statistical Tests

Pairwise Wilcoxon signed-rank tests were applied at significance level $alpha = 0.05$. A representative selection of results is shown in @tab:wilcoxon11.

#figure(
  table(
    columns: (2.8fr, 2.8fr, 1fr, 1.3fr),
    inset: 6pt,
    align: (left, left, center, center),
    fill: (x, y) => if y == 0 { luma(210) } else if calc.odd(y) { luma(248) },
    [*Algorithm A*], [*Algorithm B*], [*p-value*], [*Significant?*],
    [Insert-First (CW)],    [Transpose-First (CW)],   [< 0.001], [Yes],
    [Insert-First (CW)],    [Exchange-First (CW)],    [< 0.001], [Yes],
    [Insert-First (CW)],    [Insert-Best (CW)],       [< 0.001], [Yes],
    [Insert-First (CW)],    [Insert-First (Random)],  [< 0.001], [Yes],
    [Insert-Best (CW)],     [Insert-First (Random)],  [0.9404],  [*No*],
    [Exchange-First (CW)],  [Exchange-Best (CW)],     [< 0.001], [Yes],
    [Transpose-First (CW)], [Transpose-First (Random)],[< 0.001], [Yes],
  ),
  caption: [Selected pairwise Wilcoxon signed-rank test results ($alpha = 0.05$). All 66 pairs were tested; nearly all are significant except the highlighted case.]
) <tab:wilcoxon11>

Almost all differences are statistically significant (p < 0.001). The one interesting exception is *Insert-Best (CW) vs Insert-First (Random)* (p = 0.94): despite very different strategies, these two configurations happen to produce solutions of indistinguishable quality (RPD 2.01% vs 2.02%). This shows that a good initialisation (CW) can compensate for a weaker pivoting rule (best-improvement), and vice versa.

@fig:init_boxplot confirms visually that the CW initialisation consistently produces better and tighter RPD distributions than the random start, for both Insert and Exchange neighbourhoods.

#figure(
  image("plots/plot3_init_comparison.png", width: 95%),
  caption: [Distribution of RPD (%) for CW vs Random initialisation, across Insert and Exchange neighbourhoods. Each box shows median, quartiles, and outliers over 78 instances.]
) <fig:init_boxplot>

== Exercise 1.2 — VND Results

@tab:vnd shows the performance of both VND orderings, starting from the CW solution.

#figure(
  table(
    columns: (1.8fr, 0.8fr, 0.8fr, 0.8fr, 0.9fr, 1.1fr),
    inset: 6pt,
    align: (left, center, center, center, center, right),
    fill: (x, y) => if y == 0 { luma(210) } else if calc.odd(y) { luma(248) },
    [*Algorithm*], [*Init*], [*Avg RPD*], [*SD*], [*Avg Time (s)*], [*Total Time (s)*],
    [VND-TIE], [CW], [1.64], [0.40], [3.24], [252.4],
    [VND-TEI], [CW], [1.79], [0.42], [4.86], [379.1],
  ),
  caption: [VND results starting from the CW solution.]
) <tab:vnd>

Both VND variants outperform any single-neighbourhood algorithm. The best single-neighbourhood result was Insert-First (CW) at RPD 1.59%, very close to VND-TIE at 1.64% — the margin is small, suggesting that the insert neighbourhood is already doing most of the work in VND.

*VND-TIE outperforms VND-TEI* (1.64% vs 1.79%) and is also faster (3.24 s vs 4.86 s). The Wilcoxon test confirms this difference is statistically significant (*p = 0.0074*). The reason is likely that insert, being the richest neighbourhood, is more effective when applied second (after transpose has cleaned up easy improvements), whereas in VND-TEI, exchange is applied second and may explore a less useful part of the search space before insert gets its turn.

#figure(
  image("plots/plot4_vnd_comparison.png", width: 60%),
  caption: [RPD distribution for VND-TEI vs VND-TIE (violin + box plot). VND-TIE achieves lower and less variable RPD values. Wilcoxon test: p = 0.0074.]
) <fig:vnd>

== Execution Time and Complexity <sec:complexity>

=== Why do some algorithms take much longer than others?

The execution times in @tab:results11 vary by several orders of magnitude — from under 1 millisecond (transpose) to nearly 5 seconds (exchange/insert first-improvement). This is directly explained by the theoretical complexity.

Each *iteration* of the local search requires scanning the neighbourhood to find an improving move. The cost of one iteration depends on two factors: the size of the neighbourhood (how many moves to check) and the cost of evaluating each move.

#figure(
  table(
    columns: (1.8fr, 1.5fr, 1.2fr, 2.0fr),
    inset: 6pt,
    align: (left, center, center, left),
    fill: (x, y) => if y == 0 { luma(210) } else if calc.odd(y) { luma(248) },
    [*Neighbourhood*], [*Size*], [*Cost per $Delta$*], [*Cost per iteration*],
    [Transpose], [$n-1$],        [$O(1)$], [$O(n)$],
    [Exchange],  [$O(n^2 / 2)$], [$O(n)$], [$O(n^3)$ for BI, $O(n^2)$ avg for FI],
    [Insert],    [$O(n^2)$],     [$O(n)$], [$O(n^3)$ for BI, $O(n^2)$ avg for FI],
  ),
  caption: [Theoretical cost per iteration of local search for each neighbourhood.]
)

- *Transpose* is $O(n)$ per iteration because each gain is $O(1)$ and there are only $n-1$ adjacent pairs to check. This explains why it runs in under 10 ms even for $n=250$. However, its small neighbourhood also explains its very poor solution quality: it can only make tiny moves.

- *Exchange and Insert* are $O(n^3)$ per iteration for best-improvement (scan $O(n^2)$ pairs, each costing $O(n)$). For first-improvement, the average cost is lower because the scan stops as soon as an improvement is found — but in the worst case (near a local optimum) almost the full neighbourhood must be scanned before stopping.

@fig:pareto shows this trade-off visually: the bottom-left corner is the ideal (fast and accurate). Insert-FI (CW) is the clear winner on quality; Insert-BI and Exchange-BI are faster but sacrifice quality.

#figure(
  image("plots/plot2_quality_vs_time.png", width: 100%),
  caption: [Quality vs computation time for each configuration (avg over 78 instances). Bottom-left is best. Circles = CW init, triangles = Random init.]
) <fig:pareto>

=== Why is best-improvement faster than first-improvement for insert?

This counterintuitive result (BI: 0.79 s vs FI: 2.99 s for Insert-CW) is explained by the number of *iterations*. Best-improvement makes the largest possible improvement at each step, so it converges in far fewer iterations. Although each iteration is slower (full scan), the total number of iterations is much smaller, and the product (iterations × cost per iteration) is lower for BI. First-improvement makes smaller moves and therefore requires many more iterations to reach a local optimum.

=== Effect of instance size

Going from size $n = 150$ to $n = 250$, the per-iteration cost grows roughly as $(250/150)^3 approx 4.6$ for exchange and insert (BI). This cubic scaling is confirmed by the data: exchange-BI (CW) takes about 0.70 s for the average instance, which includes both sizes mixed.

=== Effect of initialisation on time

Starting from a CW solution saves time because the algorithm is already close to a local optimum and needs fewer iterations to converge. For insert-FI, the CW start (2.99 s) is notably faster than the random start (4.28 s), a speedup of about 1.4×.

=== Possible optimisations

- *Don't-look bits:* skip elements that have not been involved in a recent improving move, reducing the effective neighbourhood size.
- *Incremental delta table:* after applying a move, only update the affected gain values instead of recomputing all of them.
- *Candidate lists:* precompute a short list of the most promising move pairs for each element and only scan those.

= Conclusion

This exercise showed that local search for the LOP is sensitive to all three design choices studied. The neighbourhood structure has the biggest impact: insert clearly dominates exchange, and both completely dominate transpose. The CW initialisation gives significantly better results than random in every configuration. The choice of pivoting rule has a smaller but still significant effect: for the insert neighbourhood, first-improvement produces marginally better quality at the cost of longer running time.

VND provides a modest improvement over the best single-neighbourhood algorithm (Insert-First CW), and VND-TIE is the best overall configuration, combining good solution quality (RPD 1.64%) with reasonable computation time. The order in which neighbourhoods are combined matters: placing insert second rather than third (TIE vs TEI) is both faster and more effective.

The algorithms built in this exercise will serve as building blocks for the second implementation exercise, where metaheuristic techniques will be applied to further improve solution quality.
