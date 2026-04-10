/* Heuristic Optimization assignment, 2015.
    Linear Ordering Problem (LOP)
*/

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>

#include "instance.h"
#include "utilities.h"
#include "timer.h"
#include "optimization.h"

char *FileName = NULL;
int pivot_rule  = 0;   // 0=First-improvement, 1=Best-improvement
int neighborhood = 0;  // 0=Transpose, 1=Exchange, 2=Insert
int init_method  = 0;  // 0=Random, 1=CW
int vnd_ordering = -1; // -1=plain LS, 0=VND-TEI, 1=VND-TIE
int algorithm = 0; // 0 = LS/VND, 1 = SimAnnealing, 2 = ACO
double timeLimit = 0.0;
int userSeed = -1;
int verbose      = 0;

void readOpts(int argc, char **argv) {
    int opt;
    int option_index = 0;

    static struct option long_options[] = {
        {"first",     no_argument,       0, 'f'},
        {"best",      no_argument,       0, 'b'},
        {"transpose", no_argument,       0, 't'},
        {"exchange",  no_argument,       0, 'e'},
        {"insert",    no_argument,       0, 'n'},
        {"random",    no_argument,       0, 'r'},
        {"cw",        no_argument,       0, 'c'},
        {"vnd-tei",   no_argument,       0, '1'},
        {"vnd-tie",   no_argument,       0, '2'},
        {"sa",        no_argument,       0, 's'},
        {"aco",       no_argument,       0, 'a'},
        {"time",      required_argument, 0, 'T'},
        {"seed",      required_argument, 0, 'S'},
        {"instance",  required_argument, 0, 'i'},
        {"verbose",   no_argument,       0, 'v'},
        {0, 0, 0, 0}
    };

    while ((opt = getopt_long(argc, argv, "i:fbtencrv12saT:S:", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'i': FileName      = strdup(optarg);   break;
            case 'f': pivot_rule    = 0;                break;
            case 'b': pivot_rule    = 1;                break;
            case 't': neighborhood  = 0;                break;
            case 'e': neighborhood  = 1;                break;
            case 'n': neighborhood  = 2;                break;
            case 'r': init_method   = 0;                break;
            case 'c': init_method   = 1;                break;
            case '1': vnd_ordering  = 0;                break;
            case '2': vnd_ordering  = 1;                break;
            case 's': algorithm     = 1;                break;
            case 'a': algorithm     = 2;                break;
            case 'T': timeLimit     = atof(optarg);     break;
            case 'S': userSeed      = atoi(optarg);     break;
            case 'v': verbose       = 1;                break;
            default:
                fprintf(stderr,
                    "Usage: %s -i <file> [--sa|--aco] [--time <sec>] "
                    "[--seed <n>] [--first|--best] [--transpose|--exchange"
                    "|--insert] [--random|--cw] [--vnd-tei|--vnd-tie] [-v]\n",
                    argv[0]);
                exit(1);
        }
    }

    if (!FileName) {
        fprintf(stderr, "Error: no instance file provided. Use -i <filename>\n");
        exit(1);
    }
}

int main(int argc, char **argv) {
    long int i, j;
    long int *currentSolution;
    long long int initialCost, finalCost;
    double startTime, duration;

    setbuf(stdout, NULL);
    setbuf(stderr, NULL);

    readOpts(argc, argv);

    CostMat = readInstance(FileName);

    if(userSeed >= 0){
        Seed = (long int)userSeed;
    } else{
        Seed = 0;
        for (i = 0; i < PSize; i++)
            for (j = 0; j < PSize; j++)
                Seed += (long int)CostMat[i][j];
    }
    currentSolution = (long int *)malloc(PSize * sizeof(long int));

    if (verbose) {
        printf("Instance : %s (n=%ld)\n", FileName, PSize);
        if (algorithm == 1)      printf("Algorithm: Simulated Annealing\n");
        else if (algorithm == 2) printf("Algorithm: ACO (MMAS)\n");
        else if (vnd_ordering >= 0)
            printf("Algorithm: VND-%s\n", vnd_ordering == 0 ? "TEI" : "TIE");
        else
            printf("Algorithm: LS (%s, %s)\n",
                   neighborhood == 0 ? "Transpose" :
                   neighborhood == 1 ? "Exchange" : "Insert",
                   pivot_rule == 0 ? "First" : "Best");
    }


    start_timers();

    if (algorithm == 1) {
        /* --- Simulated Annealing --- */
        if (init_method == 1) createCWSolution(currentSolution);
        else createRandomSolution(currentSolution);
        initialCost = computeCost(currentSolution);

        finalCost = simulatedAnnealing(currentSolution, timeLimit);
        duration = elapsed_time(REAL);

    }
     else if (algorithm == 2) {
        // --- ACO --- 
        initialCost = 0;
        finalCost = aco(currentSolution, timeLimit);
        duration = elapsed_time(REAL);
    

    } else {
        /* --- Original LS / VND --- */
        if (init_method == 1) createCWSolution(currentSolution);
        else createRandomSolution(currentSolution);
        initialCost = computeCost(currentSolution);

        if (vnd_ordering >= 0)
            finalCost = vnd(currentSolution, vnd_ordering);
        else
            finalCost = iterativeImprovment(currentSolution,
                                            neighborhood, pivot_rule);
        duration = elapsed_time(REAL);
    }

    if (verbose) {
        printf("Initial cost : %lld\n", initialCost);
        printf("Final cost   : %lld\n", finalCost);
        printf("Time         : %.6f s\n", duration);
    } else {
        /* CSV: file;init;algo;pivot;initialCost;finalCost;time */
        int algo_id = algorithm;  /* 0=LS, 1=SA, 2=ACO */
        if (algorithm == 0) {
            algo_id = (vnd_ordering >= 0) ? (3 + vnd_ordering) : neighborhood;
        }
        printf("%s;%d;%d;%d;%lld;%lld;%.6f\n",
               FileName, init_method, algo_id, pivot_rule,
               initialCost, finalCost, duration);
    }

    free(currentSolution);
    return 0;
}
