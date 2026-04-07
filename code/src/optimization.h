/*  Heuristic Optimization assignment, 2015.
    Adapted by Jérémie Dubois-Lacoste from the ILSLOP implementation
    of Tommaso Schiavinotto:
    ---
    ILSLOP Iterated Local Search Algorithm for Linear Ordering Problem
    Copyright (C) 2004  Tommaso Schiavinotto (tommaso.schiavinotto@gmail.com)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#ifndef _LO_H_
#define _LO_H_

/*
 * Cost matrix loaded from the instance file.
 * CostMat[i][j] = benefit of placing node i directly before node j.
 */
extern long int **CostMat;

int compareElement(const void *ptr1, const void *ptr2);

/* Compute f(s) = sum_{i<j} CostMat[s[i]][s[j]]. O(n^2). */
long long int computeCost(long int *s);

/* Build a random permutation of {0,...,PSize-1}. */
void createRandomSolution(long int *s);

/*
 * Build a greedy solution using the Chenery-Watanabe heuristic:
 * place nodes in decreasing order of row-sum R_i = sum_{j!=i} CostMat[i][j].
 */
void createCWSolution(long int *s);

/*
 * Iterative improvement until a local optimum is reached.
 *
 * neighborhood : 0=Transpose, 1=Exchange, 2=Insert
 * pivot_rule   : 0=First-improvement, 1=Best-improvement
 *
 * Returns the objective value at the local optimum.
 */
long long int iterativeImprovment(long int *s, int neighborhood, int pivot_rule);

/*
 * Variable Neighbourhood Descent (first-improvement).
 * Chains Transpose, Exchange and Insert; restarts from the first
 * neighbourhood whenever an improvement is found.
 *
 * ordering : 0=TEI (Transpose->Exchange->Insert)
 *            1=TIE (Transpose->Insert->Exchange)
 */
long long int vnd(long int *s, int ordering);

/* Apply a move in-place. neighborhood: 0=Transpose, 1=Exchange, 2=Insert. */
void applyMove(long int *s, int neighborhood, int i, int j);

/* Gain of swapping adjacent positions i and i+1. O(1). */
long int deltaTranspose(long int *s, int i);

/* Gain of swapping positions i and j. O(n). */
long int deltaExchange(long int *s, int i, int j);

/* Gain of removing element at i and inserting it at j. O(n). */
long int deltaInsert(long int *s, int i, int j);

/* ==================================
 *             IMPL 2
 * ================================== */

/*
 * Simulated Annealing with insert neighborhood.
 * Starts from current solution s, runs until timeLimit (seconds).
 * Applies VND on the best solution found at the end.
 * Returns the objective value of the best solution.
 */
long long int simulatedAnnealing(long int *s, double timeLimit);



/*
 * MAX-MIN Ant System for LOP.
 * Constructs solutions using pheromone trails + heuristic info,
 * applies VND to each ant's solution.
 * Returns the objective value of the best solution found.
 */
long long int aco(long int *s, double timeLimit);

#endif
