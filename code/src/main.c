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
        {"instance",  required_argument, 0, 'i'},
        {"verbose",   no_argument,       0, 'v'},
        {0, 0, 0, 0}
    };

    while ((opt = getopt_long(argc, argv, "i:fbtencrv12", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'i': FileName    = strdup(optarg); break;
            case 'f': pivot_rule  = 0; break;
            case 'b': pivot_rule  = 1; break;
            case 't': neighborhood = 0; break;
            case 'e': neighborhood = 1; break;
            case 'n': neighborhood = 2; break;
            case 'r': init_method  = 0; break;
            case 'c': init_method  = 1; break;
            case '1': vnd_ordering = 0; break;
            case '2': vnd_ordering = 1; break;
            case 'v': verbose      = 1; break;
            default:
                fprintf(stderr, "Usage: %s -i <file> [--first|--best] [--transpose|--exchange|--insert] [--random|--cw] [--vnd-tei|--vnd-tie] [-v]\n", argv[0]);
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

    if (verbose) {
        printf("Instance      : %s (n=%ld)\n", FileName, PSize);
        printf("Initialisation: %s\n", (init_method == 0) ? "Random" : "CW");
        if (vnd_ordering >= 0)
            printf("Algorithm     : VND-%s\n", (vnd_ordering == 0) ? "TEI" : "TIE");
        else
            printf("Neighbourhood : %s  Pivot: %s\n",
                   (neighborhood == 0) ? "Transpose" : (neighborhood == 1) ? "Exchange" : "Insert",
                   (pivot_rule == 0) ? "First" : "Best");
    }

    /* seed derived from instance so results are reproducible */
    Seed = 0;
    for (i = 0; i < PSize; ++i)
        for (j = 0; j < PSize; ++j)
            Seed += (long int)CostMat[i][j];

    currentSolution = (long int *)malloc(PSize * sizeof(long int));

    if (init_method == 1)
        createCWSolution(currentSolution);
    else
        createRandomSolution(currentSolution);

    initialCost = computeCost(currentSolution);

    start_timers();
    startTime = elapsed_time(0);

    if (vnd_ordering >= 0)
        finalCost = vnd(currentSolution, vnd_ordering);
    else
        finalCost = iterativeImprovment(currentSolution, neighborhood, pivot_rule);

    duration = elapsed_time(startTime);

    if (verbose) {
        printf("Initial cost  : %lld\n", initialCost);
        printf("Final cost    : %lld\n", finalCost);
        printf("Time          : %.6f s\n", duration);
    } else {
        int nh_out    = (vnd_ordering >= 0) ? (3 + vnd_ordering) : neighborhood;
        int pivot_out = (vnd_ordering >= 0) ? 0                  : pivot_rule;
        printf("%s;%d;%d;%d;%lld;%lld;%.6f\n",
               FileName, init_method, nh_out, pivot_out, initialCost, finalCost, duration);
    }

    free(currentSolution);
    return 0;
}
