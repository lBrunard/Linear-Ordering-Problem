import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# 1. Chargement et Nettoyage
try:
    df = pd.read_csv('heuristic_optimization_lop/results_summary.csv', sep=';')
except:
    print("Fichier CSV introuvable.")
    exit()

# Mapping pour la clarté
df['Init_Label'] = df['Init'].map({0: 'Random', 1: 'CW'})
df['NH_Label'] = df['Neighborhood'].map({0: 'Transpose', 1: 'Exchange', 2: 'Insert'})
df['Pivot_Label'] = df['Pivot'].map({0: 'First', 1: 'Best'})
df['Config'] = df['NH_Label'] + " (" + df['Pivot_Label'] + ")"

# 2. CALCUL DU RPD (Relative Percentage Deviation)
# On calcule le meilleur score trouvé pour CHAQUE instance
best_scores = df.groupby('Instance')['FinalCost'].transform('max')
# Formule du RPD (plus c'est proche de 0, meilleur c'est)
df['RPD'] = ((best_scores - df['FinalCost']) / best_scores) * 100

# Configuration du style
sns.set_context("talk")
plt.style.use('seaborn-v0_8-whitegrid')

# --- GRAPHIQUE 1 : LE COMPROMIS QUALITÉ vs TEMPS (PARETO) ---
plt.figure(figsize=(12, 8))
# On groupe par configuration pour avoir un point moyen
stats = df.groupby(['Config', 'Init_Label']).agg({'RPD': 'mean', 'Time': 'mean'}).reset_index()

sns.scatterplot(data=stats, x='Time', y='RPD', hue='Config', style='Init_Label', s=200)

plt.title('Compromis Qualité (RPD) vs Temps de calcul', pad=20)
plt.xlabel('Temps moyen (secondes)')
plt.ylabel('RPD Moyen (%) - Bas est meilleur')
plt.xscale('log') # Très important car les temps varient de 0.001 à 1s
plt.grid(True, which="both", ls="-", alpha=0.5)
plt.savefig('plot_pareto_tradeoff.png', bbox_inches='tight')

# --- GRAPHIQUE 2 : IMPACT DU PIVOT SUR LE TEMPS ---
plt.figure(figsize=(10, 6))
sns.barplot(data=df, x='NH_Label', y='Time', hue='Pivot_Label', palette='muted')
plt.title('Coût temporel du Pivot : First vs Best Improvement')
plt.ylabel('Temps (s)')
plt.yscale('log')
plt.savefig('plot_pivot_impact.png', bbox_inches='tight')

# --- GRAPHIQUE 3 : PERFORMANCE PAR INITIALISATION ---
# Un FacetGrid pour comparer Random et CW côte à côte
g = sns.FacetGrid(df, col="Init_Label", height=6, aspect=1.2)
g.map_dataframe(sns.boxplot, x="NH_Label", y="RPD", palette="Set2")
g.set_axis_labels("Voisinage", "RPD (%)")
g.set_titles("Initialisation : {col_name}")
plt.savefig('plot_facet_comparison.png', bbox_inches='tight')

print("Nouveaux graphiques générés :")
print("- plot_pareto_tradeoff.png : Montre qui est le plus efficace (meilleur score en moins de temps)")
print("- plot_pivot_impact.png : Justifie le choix de la règle de pivot")
print("- plot_facet_comparison.png : Prouve l'impact de l'initialisation CW")