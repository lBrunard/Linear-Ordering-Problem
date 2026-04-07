/*  Heuristic Optimization assignment, 2015.
    Adapted by Jérémie Dubois-Lacoste from the ILSLOP implementation
    of Tommaso Schiavinotto:
    ---
    ILSLOP Iterated Lcaol Search Algorithm for Linear Ordering Problem
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

#include <stdio.h>
#include <stdlib.h>
//#include <values.h>

#include "optimization.h"
#include "instance.h"
#include "utilities.h"

#include <math.h>
#include <string.h>
#include "timer.h"

/* #ifdef __MINGW32__
#include <float.h>
#define MAX_FLOAT FLT_MAX
#else
#define MAX_FLOAT MAXFLOAT
#endif */
#include <float.h>
#define MAX_FLOAT FLT_MAX


long int **CostMat;

typedef struct{
    int index;
    long int score;
} Element;


long long int computeCost (long int *s ) {
    int h,k;
    long long int sum;

    for (sum = 0, h = 0; h < PSize; h++ )
	for ( k = h + 1; k < PSize; k++ )
	    sum += CostMat[s[h]][s[k]];
    return(sum);
}

int compareElement(const void * ptr1, const void * ptr2){
    Element *elem1 = (Element *)ptr1;
    Element *elem2 = (Element *)ptr2;

    if (elem2->score > elem1->score) return 1;
    else if (elem2->score < elem1->score) return -1;
    return 0;

}


void createRandomSolution(long int *s) {
    int j;
    long int *random;

    random = generate_random_vector(PSize);
    for ( j = 0 ; j < PSize ; j++ ) {
      s[j] = random[j];
    }
    free ( random );
}


void createCWSolution(long int *s){
    Element *elements = (Element *)malloc(PSize* sizeof(Element));

    for(int i = 0; i < PSize; i++){
        elements[i].index = i;
        elements[i].score = 0;
        for(int j = 0; j < PSize; j++){
            if(i != j) elements[i].score += CostMat[i][j];
        }
    }

    qsort(elements, PSize, sizeof(Element), compareElement);

    for(int i = 0; i < PSize; i++){
        s[i] = elements[i].index;
    }

    free(elements);
}

long long int iterativeImprovment(long int *s, int neighborhood, int pivot_rule){
    int improvement = 1;

    long long int currentCost = computeCost(s);

    while(improvement){
        improvement = 0;
        long int bestDelta = 0;
        int bestI = -1, bestJ = -1;
        int found = 0;

        /* Insert explores all (i,j) with i!=j; Transpose only j=i+1; Exchange only j>i. */
        int iLimit = (neighborhood == 2) ? PSize : PSize - 1;

        for(int i = 0; i < iLimit && !found; i++){
            for(int j = 0; j < PSize; j++){
                if(neighborhood == 0 && j != i + 1) continue;
                if(neighborhood == 1 && j <= i)     continue;
                if(neighborhood == 2 && j == i)     continue;

                long int d = 0;
                if(neighborhood == 0)      d = deltaTranspose(s, i);
                else if(neighborhood == 1) d = deltaExchange(s, i, j);
                else if(neighborhood == 2) d = deltaInsert(s, i, j);

                if(d > 0){
                    if(pivot_rule == 0){
                        applyMove(s, neighborhood, i, j);
                        currentCost += d;
                        improvement = 1;
                        found = 1;
                        break;
                    }
                    else if(d > bestDelta){
                        bestDelta = d;
                        bestI = i;
                        bestJ = j;
                    }
                }
            }
        }
        if(pivot_rule == 1 && bestDelta > 0){
            applyMove(s, neighborhood, bestI, bestJ);
            currentCost += bestDelta;
            improvement = 1;
        }
    }
    return currentCost;
}

long long int vnd(long int *s, int ordering){
    int order[3];
    if(ordering == 0){
        order[0] = 0; order[1] = 1; order[2] = 2; /* TEI */
    } else {
        order[0] = 0; order[1] = 2; order[2] = 1; /* TIE */
    }

    long long int currentCost = computeCost(s);
    int k = 0;

    while(k < 3){
        long long int newCost = iterativeImprovment(s, order[k], 0);
        if(newCost > currentCost){
            currentCost = newCost;
            k = 0;
        } else {
            k++;
        }
    }
    return currentCost;
}

void applyMove(long int *s, int neighborhood, int i, int j) {
    if (neighborhood == 0 || neighborhood == 1) {
        long int temp = s[i];
        s[i] = s[j];
        s[j] = temp;
    } else if (neighborhood == 2) {
        long int elementToMove = s[i];
        if (i < j) {
            for (int k = i; k < j; k++) s[k] = s[k+1];
        } else {
            for (int k = i; k > j; k--) s[k] = s[k-1];
        }
        s[j] = elementToMove;
    }
}


long int deltaTranspose(long int *s, int i){
    return CostMat[s[i+1]][s[i]] - CostMat[s[i]][s[i+1]];
}

long int deltaExchange (long int *s, int i, int j){
    long int gain = 0;

    if (i == j) return 0;
    if (i > j){
        int tmp = i;
        i = j;
        j = tmp;
    }

    long int g = CostMat[s[j]][s[i]] - CostMat[s[i]][s[j]];

    for(int k = i + 1; k < j; k++){
        g += (CostMat[s[j]][s[k]] - CostMat[s[i]][s[k]]) +
             (CostMat[s[k]][s[i]] - CostMat[s[k]][s[j]]);
    }

    return g;
}

long int deltaInsert(long int *s, int i, int j) {
    if (i == j) return 0;
    long int g = 0;

    if (i < j) {
        for (int k = i + 1; k <= j; k++) {
            g += CostMat[s[k]][s[i]] - CostMat[s[i]][s[k]];
        }
    } else {
        for (int k = j; k < i; k++) {
            g += CostMat[s[i]][s[k]] - CostMat[s[k]][s[i]];
        }
    }
    return g;
}

long long int simulatedAnnealing(long int *s, double timelimit){
    long long int currentCost = computeCost(s);
    long long int bestCost = currentCost;
    long int *bestSol = (long int *)malloc(PSize * sizeof(long int));
    memcpy(bestSol, s, PSize * sizeof(long int));

    double sumNeg = 0.0;
    int countNeg = 0;
    for (int t = 0; t < 500; t++){
        int i = randInt(0, PSize -1);
        int j = randInt(0, PSize -2);
        if(j >= i) j++;
        long int d = deltaInsert(s, i, j);
        if (d < 0){
            sumNeg += (double)(-d);
            countNeg++;
        }
    }

    double avgNeg = (countNeg > 0) ? sumNeg / countNeg : 1.0;
    double T0 = avgNeg / log(2.0);
    double T = T0;

    /*Params*/
    double coolingRate = 0.99;
    int iterPerTemp = PSize * 10; //Moves per temp level

    /*Main loop*/
    while (elapsed_time(REAL) < timelimit){
        for(int iter = 0; iter < iterPerTemp; iter++){
            /*Random insert Move*/
            int i = randInt(0, PSize - 1);
            int j = randInt(0, PSize - 2);
            if(j >= i) j++;

            long int delta = deltaInsert(s, i, j);

            /*Accept if improving*/
            if (delta > 0 || ran01(&Seed) < exp((double)delta / T)){
                applyMove(s, 2, i, j);
                currentCost += delta;

                if (currentCost > bestCost){
                    bestCost = currentCost;
                    memcpy(bestSol, s, PSize * sizeof(long int));
                }
            }
        }
        T *= coolingRate;
    }
    memcpy(s, bestSol, PSize * sizeof(long int));
    free(bestSol);
    bestCost = vnd(s, 0);
    return bestCost;
}


long long int aco(long int *s, double timeLimit){
    // params
    int nAnts = 10;
    double alpha = 1.0;
    double beta = 3.0;
    double rho = 0.2;
    double tauMax = 10.0;
    double tauMin = 0.1;

    //Pheromone matrix
    double **tau = (double **)malloc(PSize * sizeof(double *));
    for(int i = 0; i < PSize; i++){
        tau[i] = (double *)malloc(PSize * sizeof(double));
        for(int j = 0; j< PSize; j++){
            tau[i][j] = tauMax;
        }
    }

    //Arrays
    long int *antSol = (long int *)malloc(PSize * sizeof(long int));
    long int *iterbestSol = (long int *)malloc(PSize * sizeof(long int));
    int *available = (int *)malloc(PSize * sizeof(int));
    double *probs = (double *)malloc(PSize * sizeof(double));

    long long int bestCost = 0;

    while(elapsed_time(REAL) < timeLimit){
        long long int iterBestCost = 0;
        for(int ant = 0; ant < nAnts; ant++){

            for(int i = 0; i <PSize; i++) available[i] = 1;

            for(int pos = 0; pos <PSize; pos++){
                double sumProb = 0.0;

                for(int j = 0; j <PSize; j++){
                    if(!available[j]) {
                        probs[j] = 0.0;
                        continue;
                    }
                    double heur = 0.0;
                    double phero = 0.0;
                    for(int k = 0; k<PSize; k++){
                        if(k == j || !available[k]) continue;
                        heur += (double)CostMat[j][k];
                        phero += tau[j][k];
                    }
                    if(heur <1.0) heur = 1.0;

                    probs[j] = pow(phero, alpha) * pow(heur, beta);
                    sumProb += probs[j];
                }
                double r = ran01(&Seed) * sumProb;
                double cumul = 0.0;
                int choosen = -1;
                for(int j = 0; j<PSize; j++){
                    if(!available[j]) continue;
                    cumul += probs[j];
                    if(cumul >=r) {
                        choosen = j;
                        break;
                    }
                    if(choosen == -1){
                        for(int j = PSize-1; j >= 0; j--){
                            if(available[j]){
                                choosen = j;
                                break;
                            }
                        }
                    }
                    antSol[pos] = choosen;
                    available[choosen] = 0;
                }
                //VND on antsol
                long long int antCost = vnd(antSol, 0);
                if(antCost > iterBestCost){
                    iterBestCost = antCost;
                    memcpy(iterbestSol, antSol, PSize * sizeof(long int));
                }
            }
        }
        if(iterBestCost >bestCost){
            bestCost = iterBestCost;
            memcpy(s, iterbestSol, PSize * sizeof(long int));
        }

        //Pheromon evaporation
        for(int i = 0; i< PSize; i++){
            for(int j = 0; j <PSize; j++){
                tau[i][j] *= (1.0 - rho);
                if(tau[i][j] < tauMin) tau[i][j] = tauMin;
            }
        }
        // Pheromone deposit
        //Reinforce edges (i before j) present in best solution */
        for (int p = 0; p < PSize - 1; p++){
            for (int q = p + 1; q < PSize; q++) {
                tau[s[p]][s[q]] += 1.0;
                if (tau[s[p]][s[q]] > tauMax)
                    tau[s[p]][s[q]] = tauMax;
            }
        }
        
    }

    /*
    double **tau = (double **)malloc(PSize * sizeof(double *));
    long int *antSol = (long int *)malloc(PSize * sizeof(long int));
    long int *iterbestSol = (long int *)malloc(PSize * sizeof(long int));
    int *available = (int *)malloc(PSize * sizeof(int));
    double *probs = (double *)malloc(PSize * sizeof(double));
    */
    for (int i = 0; i < PSize; i++) free(tau[i]);
    free(tau);
    free(antSol);
    free(iterbestSol);
    free(available);
    free(probs);

    return bestCost;
}

