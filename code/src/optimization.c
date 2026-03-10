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
    
    /* Diagonal value are not considered */
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

        /* Insert explores all (i,j) pairs with i!=j (both directions).
         * Transpose only explores adjacent pairs j=i+1.
         * Exchange explores pairs with j>i. */
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
                    if(pivot_rule == 0){ // First Improvement
                        applyMove(s, neighborhood, i, j);
                        currentCost += d;
                        improvement = 1;
                        found = 1;
                        break;
                    }
                    else if(d > bestDelta){ // Best Improvement
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

/* Variable Neighborhood Descent (first-improvement only).
 * ordering 0 — TEI: Transpose -> Exchange -> Insert
 * ordering 1 — TIE: Transpose -> Insert  -> Exchange */
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
        long long int newCost = iterativeImprovment(s, order[k], 0); /* first-improvement */
        if(newCost > currentCost){
            currentCost = newCost;
            k = 0; /* improvement found: restart from first neighborhood */
        } else {
            k++;   /* no improvement: try next neighborhood */
        }
    }
    return currentCost;
}

void applyMove(long int *s, int neighborhood, int i, int j) {
    if (neighborhood == 0 || neighborhood == 1) {
        // Pour Transpose et Exchange, c'est juste un swap
        long int temp = s[i];
        s[i] = s[j];
        s[j] = temp;
    } else if (neighborhood == 2) {
        // Pour Insert, il faut décaler les éléments entre i et j
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
