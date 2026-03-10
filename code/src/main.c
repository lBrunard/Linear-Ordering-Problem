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

/* --- Global Variables --- */
char *FileName = NULL;
int pivot_rule = 0;    // 0 = First-Improvement, 1 = Best-Improvement
int neighborhood = 0;  // 0 = Transpose, 1 = Exchange, 2 = Insert
int init_method = 0;   // 0 = Random, 1 = CW
int vnd_ordering = -1; // -1 = plain LS, 0 = VND-TEI, 1 = VND-TIE
int verbose = 0;       // 0 = Quiet, 1 = Full output

/* --- Argument Parsing --- */
void readOpts(int argc, char **argv) {
    int opt;
    int option_index = 0;

    static struct option long_options[] = {
        {"first",     no_argument,       0, 'f'},
        {"best",      no_argument,       0, 'b'},
        {"transpose", no_argument,       0, 't'},
        {"exchange",  no_argument,       0, 'e'},
        {"insert",    no_argument,       0, 'n'}, // 'n' pour iNsert
        {"random",    no_argument,       0, 'r'},
        {"cw",        no_argument,       0, 'c'},
        {"vnd-tei",   no_argument,       0, '1'},
        {"vnd-tie",   no_argument,       0, '2'},
        {"instance",  required_argument, 0, 'i'},
        {"verbose",   no_argument,       0, 'v'},
        {0, 0, 0, 0}
    };

    while ((opt = getopt_long(argc, argv, "i:fbtencrv12", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'i': FileName = strdup(optarg); break;
            case 'f': pivot_rule = 0; break;
            case 'b': pivot_rule = 1; break;
            case 't': neighborhood = 0; break;
            case 'e': neighborhood = 1; break;
            case 'n': neighborhood = 2; break;
            case 'r': init_method = 0; break;
            case 'c': init_method = 1; break;
            case '1': vnd_ordering = 0; break; // VND-TEI
            case '2': vnd_ordering = 1; break; // VND-TIE
            case 'v': verbose = 1; break;
            default:
                fprintf(stderr, "Usage: %s -i <file> [--first|--best] [--transpose|--exchange|--insert] [--random|--cw] [--vnd-tei|--vnd-tie] [-v]\n", argv[0]);
                exit(1);
        }
    }

    if (!FileName) {
        fprintf(stderr, "Error: No instance file provided. Use -i <filename>\n");
        exit(1);
    }
}

/* --- Main Program --- */
int main(int argc, char **argv) {
    long int i, j;
    long int *currentSolution;
    long long int initialCost, finalCost;
    double startTime, duration;

    /* Disable buffering for clean logs */
    setbuf(stdout, NULL);
    setbuf(stderr, NULL);

    /* 1. Parse Options */
    readOpts(argc, argv);

    /* 2. Load Instance */
    CostMat = readInstance(FileName);
    
    if (verbose) {
        printf("========================================\n");
        printf(" LOP Solver - Configuration\n");
        printf("========================================\n");
        printf("Instance      : %s (Size: %ld)\n", FileName, PSize);
        printf("Initialisation: %s\n", (init_method == 0) ? "Random" : "Chenery-Watanabe (CW)");
        if (vnd_ordering >= 0) {
            printf("Algorithm     : VND (%s)\n", (vnd_ordering == 0) ? "TEI" : "TIE");
        } else {
            printf("Neighborhood  : %s\n", (neighborhood == 0) ? "Transpose" : (neighborhood == 1) ? "Exchange" : "Insert");
            printf("Pivot Rule    : %s\n", (pivot_rule == 0) ? "First-improvement" : "Best-improvement");
        }
        printf("----------------------------------------\n");
    }

    /* 3. Setup RNG Seed */
    Seed = 0;
    for (i = 0; i < PSize; ++i)
        for (j = 0; j < PSize; ++j)
            Seed += (long int)CostMat[i][j];
    
    // On pourrait utiliser Seed pour srand() si utilities.h ne le fait pas
    // srand(Seed); 

    /* 4. Initial Solution */
    currentSolution = (long int *)malloc(PSize * sizeof(long int));

    if (init_method == 1) {
        createCWSolution(currentSolution);
    } else {
        createRandomSolution(currentSolution);
    }

    initialCost = computeCost(currentSolution);

    if (verbose) {
        printf("Initial Solution generated.\n");
        printf("Initial Cost: %lld\n", initialCost);
        if (PSize <= 50) { // On n'affiche que si c'est lisible
            printf("Permutation: ");
            for (j = 0; j < PSize; j++) printf("%ld ", currentSolution[j]);
            printf("\n");
        }
        printf("----------------------------------------\n");
    }

    /* 5. Local Search */
    if (verbose) printf("Running Local Search...\n");

    start_timers();
    startTime = elapsed_time(0);

    if (vnd_ordering >= 0) {
        finalCost = vnd(currentSolution, vnd_ordering);
    } else {
        finalCost = iterativeImprovment(currentSolution, neighborhood, pivot_rule);
    }

    duration = elapsed_time(startTime);

    /* 6. Final Results */
    if (verbose) {
        printf("Optimization complete.\n");
        printf("Final Cost  : %lld\n", finalCost);
        printf("Improvement : %lld\n", finalCost - initialCost);
        printf("Time        : %.6f seconds\n", duration);
        printf("========================================\n");
    } else {
        /* Format compact pour les expérimentations massives (CSV-like)
         * Instance;Init;NH;Pivot;InitCost;FinalCost;Time
         * NH = 3 -> VND-TEI, NH = 4 -> VND-TIE (pivot_rule = 0 for VND) */
        int nh_out    = (vnd_ordering >= 0) ? (3 + vnd_ordering) : neighborhood;
        int pivot_out = (vnd_ordering >= 0) ? 0                  : pivot_rule;
        printf("%s;%d;%d;%d;%lld;%lld;%.6f\n",
               FileName, init_method, nh_out, pivot_out, initialCost, finalCost, duration);
    }

    /* Cleanup */
    free(currentSolution);
    // freeInstance() si disponible dans instance.h
    
    return 0;
}