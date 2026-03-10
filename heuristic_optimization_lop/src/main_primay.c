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

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>

#include "instance.h"
#include "utilities.h"
#include "timer.h"
#include "optimization.h"

char *FileName;

// --- Configuration ---
int pivot_rule = 0;    // 0 = First-Improvment,  1 = Best-improve
int neighborhood = 0;  // 0 = Transpose,         1 = Exchange,       2 = Insert
int init_method = 0;   // 0 = Random,            1 = CW

int verbose = 0;

void readOpts(int argc, char **argv) {
  int opt;
  int option_index = 0;

  static struct option long_option[] = {
    {"first",       no_argument,      0,    'f'},
    {"best",        no_argument,      0,    'b'},
    {"transpose",   no_argument,      0,    't'},
    {"exchange",    no_argument,      0,    'e'},
    {"insert",      no_argument,      0,    'in'},
    {"random",      no_argument,      0,    'r'},
    {"cw",          no_argument,      0,    'c'},
    {"instance",    required_argument,0,    'i'},
    {"verbose",    no_argument,      0,    'v'},
    {0,0,0,0}
  };


  FileName = NULL;
  /* Initial Version
  while ( (opt = getopt(argc, argv, "i:")) > 0 )  
      switch (opt) {
	  case 'i':
	      FileName = (char *)malloc(strlen(optarg)+1);
	      strncpy(FileName, optarg, strlen(optarg));
	      break;
	  default:
	      fprintf(stderr, "Option %c not managed.\n", opt);
      }
  */

  while((opt = getopt_long(argc, argv, "i:fbtencr", long_option, &option_index)) != -1){
    switch(opt){
      case 'i': //Instance File
        FileName = strdup(optarg);
        break;
      case 'f': //First-Improvment
        pivot_rule = 0;
        break;
      case 'b': // Best-Improvment 
        pivot_rule = 1;
        break;
      case 't': //Transpose
        neighborhood = 0;
        break;
      case 'e': //EXchange
        neighborhood = 1;
        break;
      case 'in': //Insert
        neighborhood = 2;
        break;
      case 'r'://Random Init
        init_method = 0;
        break;
      case 'c'://CW init
        init_method = 1;
        break;
      case 'v': //Verbose mode
        verbose = 1;
        break;
      default:
        fprintf(stderr, "No option recognized.\n");
        exit(1);
    }
  }
    
  if ( !FileName ) {
    //printf("No instance file provided (use -i <instance_name>). Exiting.\n");
    printf("Usage: %s -i <file> [--first|--best] [--transpose|--exchange|--insert] [--random|--cw]\n", argv[0]);
    exit(1);
  }
}



int main (int argc, char **argv) 
{
  long int i,j;
  long int *currentSolution;
  int cost, newCost, temp, firstRandomPosition, secondRandomPosition;

  /* Do not buffer output */
  setbuf(stdout,NULL);
  setbuf(stderr,NULL);
  
  if (argc < 2) {
    printf("No instance file provided (use -i <instance_name>). Exiting.\n");
    exit(1);
  }
  
  /* Read parameters */
  readOpts(argc, argv);
  printf("Choosen config :\n");
  printf("- Pivot : %s\n", (pivot_rule == 0) ? "First-improvement" : "Best-improvement");
  printf("- Neighborhood : %s\n", (neighborhood == 0) ? "Transpose" : (neighborhood == 1) ? "Exchange" : "Insert");
  printf("- Initialisation : %s\n", (init_method == 0) ? "Random" : "CW");

  /* Read instance file */
  CostMat = readInstance(FileName);
  printf("Data have been read from instance file. Size of instance = %ld.\n\n", PSize);

  /* initialize random number generator, deterministically based on instance.
   * To do this we simply set the seed to the sum of elements in the matrix, so it is constant per-instance,
   but (most likely) varies between instances */
  Seed = (long int) 0;
    for (i=0; i < PSize; ++i)
      for (j=0; j < PSize; ++j)
        Seed += (long int) CostMat[i][j];
  printf("Seed used to initialize RNG: %ld.\n\n", Seed);
  
  /* starts time measurement */
  start_timers();

  /* A solution is just a vector of int with the same size as the instance */
  currentSolution = (long int *)malloc(PSize * sizeof(long int));

  /* Create an initial random solution. 
     The only constraint is that it should always be a permutation */
  switch (init_method){
    case 0:
      createRandomSolution(currentSolution);
      break;
    case 1:
      createCWSolution(currentSolution);
      break;
    
    default:
      break;
  }

  /* Print solution */
  printf("Initial solution:\n");
  for (j=0; j < PSize; j++) 
    printf(" %ld", currentSolution[j]);
  printf("\n");

  /* Compute cost of solution and print it */
  cost = computeCost(currentSolution);
  printf("Cost of this initial solution: %d\n\n", cost);

  /*
  // Example: apply an exchange operation of two elements at random position 
  firstRandomPosition = randInt(0,PSize-1);
  // Ensure second position is different from first one:
  secondRandomPosition = firstRandomPosition + randInt(1,(PSize-2));
  if (secondRandomPosition >= PSize)
    secondRandomPosition -= PSize;

  printf("Two positions exchanged: %d and %d. ", firstRandomPosition, secondRandomPosition);

  temp = currentSolution[firstRandomPosition];
  currentSolution[firstRandomPosition] = currentSolution[secondRandomPosition];
  currentSolution[secondRandomPosition] = temp;

  printf("Solution after exchange:\n");
  for (j=0; j < PSize; j++) 
    printf(" %ld", currentSolution[j]);
  printf("\n");

  // Recompute cost of solution after the exchange move /
  // There are some more efficient way to do this, instead of recomputing everything... /
  newCost = computeCost(currentSolution);
  printf("Cost of this solution after applying the exchange move: %d\n", newCost);
  

  

  if (newCost == cost)
    printf("Second solution is as good as first one\n");
  else if (newCost > cost)
    printf("Second solution is better than first one\n");
  else
    printf("Second solution is worse than first one\n");

  printf("Time elapsed since we started the timer: %g\n\n", elapsed_time(VIRTUAL));
  */
  // --- ACTIVE TA RECHERCHE LOCALE ---
  printf("\nLancement de la recherche locale...\n");

  double startTime = elapsed_time(0); // On lance le chrono juste avant la boucle

  // On appelle ta fonction qui contient la boucle while(improvement)
  long long int finalCost = iterativeImprovment(currentSolution, neighborhood, pivot_rule);

  double duration = elapsed_time(startTime);

  printf("Recherche terminée.\n");
  printf("Coût final : %lld\n", finalCost);
  printf("Temps de calcul : %.6f secondes\n", duration);

  return 0;
}
