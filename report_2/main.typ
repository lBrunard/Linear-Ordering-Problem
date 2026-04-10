// ============================================================
//  INFO-H-413 — Heuristic Optimization
//  Implementation Exercise 2 — Linear Ordering Problem
// ============================================================
#set page(paper: "a4", margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm), numbering: "1")
#set text(font: "New Computer Modern", size: 11pt, lang: "en")
#set par(justify: true, leading: 0.72em)
#set heading(numbering: "1.")

#let appendix(body) = {
  set heading(numbering: "A", supplement: [Appendix])
  counter(heading).update(0)
  body
}

// ---- Title ------------------------------------------------------------------
#align(center)[
  #v(0.4cm)
  #text(size: 16pt, weight: "bold")[
    Stochastic Local Search Algorithms for the \
    Linear Ordering Problem
  ]
  #v(0.25cm)
  #text(size: 12pt)[INFO-H-413 — Heuristic Optimization — Implementation Exercise 2]
  #v(0.15cm)
  #text(size: 11pt, style: "italic")[Universit\u{00e9} Libre de Bruxelles — 2026]
  #v(0.4cm)
  #text(size: 11pt, style: "italic")[Luis Brunard (577721)]
  #v(0.4cm)
]

#line(length: 100%, stroke: 0.8pt)
#v(0.3cm)
#align(center)[*_Abstract_*]
#par(first-line-indent: 0pt)[
// TODO: write abstract after experiments
_We design and evaluate two stochastic local search algorithms for the Linear Ordering Problem: Simulated Annealing (SA) and a MAX--MIN Ant System (MMAS). Both build on the VND local search from the first implementation exercise. SA explores the search space through random insert moves with a temperature-controlled acceptance criterion. MMAS constructs solutions using pheromone trails and heuristic information, then refines each one with VND. Both algorithms are evaluated on all instances of size 150 and compared using Wilcoxon signed-rank tests and run-time distributions._
]
#line(length: 100%, stroke: 0.8pt)

#v(0.3cm)

// ---- 1. Introduction --------------------------------------------------------
= Introduction

In the first implementation exercise, we studied iterative improvement algorithms for the Linear Ordering Problem (LOP). We found that Insert with first-improvement and CW initialisation gives the best single-neighbourhood results, and that VND-TIE slightly improves on it. But all these methods stop at the first local optimum they reach. There is no mechanism to escape and keep searching.

This exercise addresses that limitation. We implement two stochastic local search (SLS) algorithms that can escape local optima and continue exploring the search space over a longer time budget. The two methods come from different classes: Simulated Annealing is a simple SLS method, and MAX--MIN Ant System is a population-based method. Both use VND from the first exercise as a building block.

The question we are trying to answer is whether these more sophisticated methods can find significantly better solutions than plain local search, and how they compare to each other.

= Algorithms

== Simulated Annealing <sec:sa>

Simulated Annealing (SA) is inspired by the annealing process in metallurgy #cite(<kirkpatrick_sa>). The idea is to allow the search to accept worsening moves with some probability, so that it can escape local optima. That probability decreases over time: early on the algorithm explores freely, later it becomes more selective and converges.

=== Initial solution

We start from a CW solution (Chenery--Watanabe heuristic, as described in the first exercise). CW ranks elements by their row-sum score and gives a reasonable starting point without any local search overhead. We do not apply VND before SA starts, so the full time budget is available for the SA search itself.

=== Neighbourhood and move generation

We use the *insert neighbourhood*: pick a random element at position $i$ and reinsert it at a random position $j eq.not i$. This was the strongest neighbourhood in the first exercise and it gives SA enough freedom to rearrange the permutation significantly in a single step. At each iteration, one random insert move is sampled. The gain $Delta$ is computed using the $O(n)$ delta evaluation from the first exercise.

=== Acceptance criterion

If the move improves the solution ($Delta > 0$), it is always accepted. If it worsens it ($Delta < 0$), it is accepted with probability:

$ P("accept") = exp(Delta / T) $

where $T$ is the current temperature. When $T$ is high, the exponential is close to 1 and almost everything is accepted. When $T$ is low, only small degradations have a chance.

=== Temperature schedule

The initial temperature $T_0$ is calibrated automatically. Before starting the main loop, we sample 500 random insert moves and compute the average absolute value of the worsening deltas. We set $T_0$ so that roughly 50% of those moves would be accepted:

$ T_0 = overline(|Delta^(-)|) / ln(2) $

This avoids having to guess a problem-specific temperature. The cooling follows a geometric schedule: after each temperature level, we multiply $T$ by a cooling rate $alpha = 0.99$. Each temperature level consists of $L = n times 10$ random moves, where $n$ is the instance size. This gives a slow enough cooling that the algorithm has time to explore at each temperature.

=== Final refinement

When the time limit is reached, we take the best solution found during the entire SA run and apply VND-TEI to it. This ensures that the final solution is at least a local optimum with respect to all three neighbourhoods.

=== Summary

#block(inset: (left: 0.5cm))[
- *Initialisation:* CW heuristic
- *Neighbourhood:* Insert (random move at each step)
- *Acceptance:* Metropolis criterion with Boltzmann probability
- *Cooling:* Geometric ($alpha = 0.99$), $L = 10n$ moves per level
- *Calibration:* $T_0$ set from average worsening delta (50% acceptance)
- *Post-processing:* VND on the best solution found
]

== MAX--MIN Ant System <sec:aco>

Ant Colony Optimisation (ACO) is a population-based metaheuristic inspired by the foraging behaviour of ants #cite(<wiki_aco>). A colony of artificial ants constructs solutions probabilistically, guided by pheromone trails that encode information from previous good solutions. We use the MAX--MIN Ant System (MMAS) variant #cite(<stutzle_mmas>), which bounds the pheromone values to avoid premature convergence.

=== Pheromone representation

We maintain a pheromone matrix $tau in RR^(n times n)$, where $tau_(i j)$ represents the learned desirability of placing element $i$ before element $j$ in the permutation. All entries are initialised to $tau_"max"$ at the start, which encourages exploration in the first iterations.

=== Construction phase

Each ant builds a complete permutation by placing elements one at a time. At each step, the ant has a set $R$ of remaining (unplaced) elements. For each candidate $j in R$, we compute:

- A *pheromone score*: $phi(j) = sum_(k in R, k eq.not j) tau_(j k)$, which measures how much past experience favours placing $j$ before the other remaining elements.

- A *heuristic score*: $eta(j) = sum_(k in R, k eq.not j) c_(j k)$, which is the direct benefit of placing $j$ before the remaining elements according to the cost matrix.

The probability of choosing element $j$ is then:

$ p(j) = frac([phi(j)]^alpha dot [eta(j)]^beta, sum_(l in R) [phi(l)]^alpha dot [eta(l)]^beta) $

where $alpha$ and $beta$ control the relative importance of pheromone versus heuristic information. We use $alpha = 1$ and $beta = 3$, giving more weight to the problem-specific heuristic while still letting pheromone guide the search toward previously successful regions.

=== Local search

After construction, each ant's solution is improved using *VND-TEI* (Transpose $arrow$ Exchange $arrow$ Insert, first-improvement). This is the most important step: the constructed solution is typically far from a local optimum, and VND brings it to a much better quality. Without this step, ACO would not be competitive with SA.

=== Pheromone update

After all ants have constructed and improved their solutions, the pheromone matrix is updated in two phases:

*Evaporation.* All pheromone values are reduced by a factor $(1 - rho)$:
$ tau_(i j) <- (1 - rho) dot tau_(i j) $
This gradually forgets old information and prevents the accumulation of pheromone on suboptimal edges. We use $rho = 0.2$.

*Deposit.* The best-so-far solution reinforces the pheromone on its edges. For every pair of positions $(p, q)$ with $p < q$ in the best permutation:
$ tau_(s^*_p, s^*_q) <- tau_(s^*_p, s^*_q) + 1 $

Using the best-so-far solution (rather than the iteration-best) provides a stronger learning signal and pushes the colony toward the best known region of the search space.

*Bounds.* After each update, all pheromone values are clamped to $[tau_"min", tau_"max"]$. This is the core mechanism of MMAS: it prevents any trail from becoming so dominant that the construction becomes deterministic, and it prevents unused trails from vanishing completely.

=== Parameters

#figure(
  table(
    columns: (1.5fr, 1fr, 3fr),
    inset: 6pt,
    align: (left, center, left),
    fill: (x, y) => if y == 0 { luma(210) } else if calc.odd(y) { luma(248) },
    [*Parameter*], [*Value*], [*Role*],
    [$m$ (ants)],       [10],   [Number of solutions constructed per iteration],
    [$alpha$],          [1.0],  [Pheromone weight in construction probability],
    [$beta$],           [3.0],  [Heuristic weight in construction probability],
    [$rho$],            [0.2],  [Evaporation rate],
    [$tau_"max"$],      [10.0], [Upper bound on pheromone values],
    [$tau_"min"$],      [0.1],  [Lower bound on pheromone values],
  ),
  caption: [ACO parameter settings.]
) <tab:aco_params>

The number of ants $m = 10$ is a compromise between diversity (more ants explore more of the search space per iteration) and cost (each ant requires a full VND run). With $n = 150$, each VND call takes a non-negligible amount of time, so using too many ants would leave too few iterations for pheromone learning.

The choice $beta = 3$ gives a strong bias toward the heuristic information. This makes sense because the CW-style heuristic (sum of row weights) is already a good predictor of element quality. The pheromone then fine-tunes the ordering based on experience.

=== Summary

#block(inset: (left: 0.5cm))[
- *Construction:* Probabilistic, guided by pheromone ($tau$) and heuristic ($eta$)
- *Local search:* VND-TEI applied to every constructed solution
- *Pheromone update:* Evaporation ($rho = 0.2$) + deposit on best-so-far
- *Bounds:* MMAS with $tau in [0.1, 10.0]$
- *Colony size:* 10 ants per iteration
]


= Experimental Setup

== Instances and termination criterion

Both algorithms were run once on each instance of size 150. The termination criterion is defined as:

$ t_"max" = overline(t_"VND") times 500 $

where $overline(t_"VND")$ is the average computation time of a full VND run on instances of the same size (`Average VND time : 0.205279s`), measured in the first exercise. This gives a time budget long enough for the SLS algorithms to perform meaningful search (`Time limit (x500): 102.64s`).


== Implementation

The solver is written in C, compiled with GCC and `-O3` on macOS (Apple M5). Both SA and ACO reuse the VND, delta evaluation functions, and instance reader from the first exercise. The random number generator is the same pseudo-random generator from Numerical Recipes used throughout the project. Seeds can be set via the `--seed` command-line flag to allow reproducible runs.

== Evaluation metric

We use the same *Relative Percentage Deviation* (RPD) as in the first exercise:

$ "RPD" = frac("BestKnown" - "FinalCost", "BestKnown") times 100 $

Lower is better. An RPD of 0 means we matched the best-known solution.

= Results and Analysis

== Exercise 2.1 — SLS Results on Size 150 Instances

@tab:results_sls shows the main results for both algorithms across all instances of size 150.

#figure(
  table(
    columns: (1.5fr, 0.75fr, 0.75fr, 0.75fr, 0.9fr),
    inset: 6pt,
    align: (left, center, center, center, center),
    fill: (x, y) => if y == 0 { luma(210) } else if calc.odd(y) { luma(248) },
    [*Algorithm*], [*Avg RPD*], [*SD*], [*Min RPD*], [*Max RPD*],
    // TODO: fill with experimental values
    [Simulated Annealing],  [], [], [], [],
    [ACO (MMAS)],           [], [], [], [],
  ),
  caption: [Average RPD (%) over all size-150 instances for each SLS algorithm.]
) <tab:results_sls>


// TODO: add per-instance results table if needed
// TODO: add bar chart comparing SA vs ACO (plots/plot1_rpd_comparison.png)

// Uncomment when plot is ready:
// #figure(
//   image("plots/plot1_rpd_comparison.png", width: 70%),
//   caption: [Average RPD (%) for SA and ACO on size-150 instances.]
// ) <fig:rpd_comparison>


=== Correlation Plot

// TODO: add correlation plot (plots/plot2_correlation.png)
// The correlation plot shows, for each instance, the RPD of SA on the x-axis
// and the RPD of ACO on the y-axis. Points above the diagonal mean ACO is worse;
// points below mean ACO is better.

// Uncomment when plot is ready:
// #figure(
//   image("plots/plot2_correlation.png", width: 65%),
//   caption: [
//     Correlation plot of RPD values: SA (x-axis) vs ACO (y-axis). Each point is one instance of size 150. The dashed line is $y = x$. Points below the line favour ACO; points above favour SA.
//   ]
// ) <fig:correlation>

=== Observations

// TODO: write observations based on the results
// Possible points to discuss:
// - Which algorithm has lower average RPD?
// - Is the difference consistent across instances or driven by a few outliers?
// - How do both compare to plain VND from Exercise 1?
// - Does the correlation plot show a clear trend or is it scattered?

=== Statistical Tests

We apply the Wilcoxon signed-rank test at significance level $alpha = 0.05$ to determine whether the difference between SA and ACO is statistically significant #cite(<wiki_wilcoxon>).

#figure(
  table(
    columns: (1.8fr, 1.8fr, 1fr, 1.3fr),
    inset: 6pt,
    align: (left, left, center, center),
    fill: (x, y) => if y == 0 { luma(210) } else if calc.odd(y) { luma(248) },
    [*Algorithm A*], [*Algorithm B*], [*p-value*], [*Significant?*],
    // TODO: fill with test results
    [SA], [ACO (MMAS)], [], [],
    [SA], [VND-TIE (Ex.~1)], [], [],
    [ACO (MMAS)], [VND-TIE (Ex.~1)], [], [],
  ),
  caption: [Wilcoxon signed-rank test results ($alpha = 0.05$) comparing the SLS algorithms and the best configuration from Exercise 1.]
) <tab:wilcoxon>

// TODO: interpret the p-values
// - Is the difference between SA and ACO significant?
// - Do both SLS methods significantly outperform VND from Exercise 1?


== Exercise 2.1 — Run-Time Distributions

Run-time distributions (RTDs) measure how the probability of finding a solution of a given quality evolves over time. For each algorithm, we ran 25 independent repetitions on the first two instances of size 150, with a cut-off time of $10 times t_"max"$.

The target solution quality was set to a value within 0.5% of the best-known solution:
$ "target" = "BestKnown" times (1 - 0.005) $

// TODO: adjust the target percentage if needed (0.1%, 0.25%, or 0.5%)

// TODO: add RTD plots (plots/plot3_rtd_instance1.png, plots/plot4_rtd_instance2.png)

// Uncomment when plots are ready:
// #figure(
//   image("plots/plot3_rtd_instance1.png", width: 70%),
//   caption: [
//     Run-time distribution on the first instance of size 150. Each curve shows the fraction of runs (out of 25) that reached the target quality as a function of time.
//   ]
// ) <fig:rtd1>

// #figure(
//   image("plots/plot4_rtd_instance2.png", width: 70%),
//   caption: [
//     Run-time distribution on the second instance of size 150.
//   ]
// ) <fig:rtd2>

=== Observations

// TODO: interpret the RTD plots
// Possible points:
// - Which algorithm reaches the target faster?
// - Does one algorithm have a higher success rate within the cut-off?
// - Are the curves steep (reliable) or flat (inconsistent)?
// - How do the two instances differ in difficulty?



= Conclusion

// TODO: write conclusion after experiments
// Points to address:
// - Which SLS algorithm performs best on the LOP instances of size 150?
// - How large is the improvement over plain VND from Exercise 1?
// - Is the difference statistically significant?
// - What do the RTD plots tell us about reliability and speed?
// - Any observations about parameter sensitivity?
// - Which algorithm would you recommend for the LOP?



#bibliography("refs.bib", title: "References", style: "ieee")
