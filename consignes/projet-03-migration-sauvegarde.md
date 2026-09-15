# Projet 3 — Migration et sauvegarde d'un poste existant

> Énoncé fourni par le formateur. Reproduit ici à titre de référence du cahier des charges.

**Cours de référence :** IT Essentials — Mettre en service un poste de travail ICT avec le système d'exploitation
**Classe :** E1B
**Niveau :** Intermédiaire
**Durée :** 1 semaine (PPE)

## Contexte

Un poste de travail existant doit être remplacé ou réinstallé. Les données et les paramètres de l'utilisateur doivent être préservés et restitués à l'identique après l'opération.

## Objectifs pédagogiques

- Inventorier les données et les configurations d'un poste existant.
- Mettre en œuvre une sauvegarde complète sur un support externe.
- Vérifier l'intégrité d'une sauvegarde avant toute opération destructrice.
- Réinstaller proprement un système d'exploitation.
- Restaurer les données et démontrer leur intégrité.
- Rédiger une procédure de migration réutilisable.

## Consignes / Étapes

1. Inventorier les données et les configurations du poste existant.
2. Sauvegarder les données sur un support externe.
3. **Vérifier l'intégrité de la sauvegarde.**
4. Réinstaller le système d'exploitation.
5. Restaurer les données et les paramètres.
6. **Vérifier l'intégrité des données après restauration.**

## Livrables attendus

- Le poste migré, prêt pour démonstration.
- Un rapport technique documentant l'intervention.
- Une procédure de migration réutilisable.
- Les preuves de la vérification d'intégrité.

## Critères d'évaluation

| Critère | Pondération |
|---|---|
| Exhaustivité de l'inventaire et de la sauvegarde | 25 % |
| Qualité de la réinstallation | 20 % |
| **Intégrité de la restauration des données** | **30 %** |
| Clarté et réutilisabilité de la procédure | 25 % |

## Notation et évaluation

L'évaluation du projet suit le barème en vigueur à Geneva Institute of Technology (échelle suisse, note sur 6, seuil de réussite **4.0/6**).

**Formule de conversion :** `Note = 1 + (Total des points obtenus en % / 100) × 5`

| % obtenu | Note /6 (indicatif) |
|---|---|
| 40 % | 3.0 |
| 50 % | 3.5 |
| 60 % | 4.0 |
| 70 % | 4.5 |
| 80 % | 5.0 |
| 90 % | 5.5 |
| 100 % | 6.0 |

> Le barème détaillé (répartition des points par critère) est donné dans le tableau **Critères d'évaluation** ci-dessus. Le formateur référent peut ajuster la pondération pour un groupe/binôme après validation préalable auprès des étudiants.

---

### Correspondance consignes / rapport

| Consigne | Traitée dans |
|---|---|
| 1. Inventorier les données et les configurations | §4.2 du rapport — inventaire des fichiers avec empreintes SHA-256 (captures 04, 05) **et** relevé des configurations non-fichier : nom de machine, comptes, réseau, imprimantes, logiciels (captures 07b-1, 07b-2) |
| 2. Sauvegarder sur un support externe | §4.1.3 et §4.3.1 — disque additionnel formaté NTFS nommé `SAUVEGARDE`, copie par `robocopy` avec périmètre identique à l'inventaire (captures 03, 06) |
| 3. **Vérifier l'intégrité de la sauvegarde** | §4.3.2 — comparaison des inventaires 01 et 02, verdict `11 fichiers vérifiés, 0 écart` (capture 07) |
| 4. Réinstaller le système d'exploitation | §4.4 — installation personnalisée de Windows 11 **Professionnel** 24H2, édition conservée, disque système intégralement effacé (captures 09, 09b, 10) |
| 5. Restaurer les données et les paramètres | §4.5.1 et §4.6 — restauration par `robocopy`, recréation du compte `tech.pg`, rétablissement du nom de machine et de la configuration (captures 11, 14a, 14b) |
| 6. **Vérifier l'intégrité après restauration** | §4.5.2 — comparaison de l'inventaire d'origine et de l'inventaire post-réinstallation, verdict `11 fichiers vérifiés, 0 écart` (capture 12), complétée par un contrôle d'usage (capture 13) |
| Procédure réutilisable | Document séparé : [`procedure-migration.md`](../procedure-migration.md) — 12 étapes, liste de contrôle, tableau des points de vigilance |
