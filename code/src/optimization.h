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

extern long int **CostMat;

int compareElement(const void * ptr1, const void * ptr2);

long long int computeCost ( long int *lo );
void createRandomSolution(long int *s);

void createCWSolution(long int *s);


long long int iterativeImprovment(long int *s, int neighborhood, int pivot_rule);
long long int vnd(long int *s, int ordering);

void applyMove(long int *s, int neighborhood, int i, int j);

long int deltaTranspose(long int *s, int i);
long int deltaExchange(long int *s, int i, int j);
long int deltaInsert(long int *s, int i, int j);




#endif
