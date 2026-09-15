# Procédure de migration d'un poste de travail avec vérification d'intégrité

**Mode opératoire réutilisable**

| | |
|---|---|
| **Version** | 1.0 — 15.09.2026 |
| **Auteur** | P.G |
| **Objet** | Migrer un poste Windows vers un nouveau système sans perte de données, et **prouver** la fidélité de la restauration |
| **Durée estimée** | 2 h 00 à 2 h 30, dont 30 min d'attente d'installation |
| **Prérequis techniques** | Droits administrateur sur le poste · Support de sauvegarde d'une capacité ≥ 2 × le volume des données · Média d'installation du système cible |

> Ce document est **autonome**. Il ne suppose pas d'avoir lu le rapport d'intervention qui l'accompagne, et peut être appliqué par un autre technicien sur un autre poste.

---

## Principes à respecter

Quatre règles conditionnent le reste. Elles ne sont pas négociables selon les circonstances.

**1. Rien n'est effacé avant qu'une vérification d'intégrité ait réussi.**
Une copie n'est pas une sauvegarde tant qu'elle n'a pas été vérifiée. Tant que le verdict n'est pas rendu, le disque source ne se touche pas.

**2. La vérification se fait par empreinte, jamais par comptage ou par taille.**
Un fichier corrompu pendant une copie conserve presque toujours sa taille. Compter les fichiers ou comparer les octets ne détecte pas ce cas — l'empreinte si.

**3. Le support de sauvegarde n'est connecté que pendant la sauvegarde et pendant la restauration.**
À l'écran de partitionnement, l'installateur affiche tous les disques visibles. Effacer le mauvais est irréversible. Si le support ne peut pas être physiquement déconnecté, une copie doit exister ailleurs (voir étape 5).

**4. Ce qui n'est pas un fichier se relève par écrit avant l'effacement.**
Nom de machine, comptes, réseau, imprimantes, logiciels : ces informations ne se copient pas et disparaissent avec le formatage.

---

## Étape 0 — Préparer le poste de travail du technicien

**Objectif :** disposer des outils sans polluer les données du client.

1. Créer un dossier de travail **hors du profil utilisateur** :

```powershell
New-Item -ItemType Directory -Force -Path C:\Outils
```

2. Y déposer `p3-inventaire.ps1` et `p3-comparer.ps1`.

3. Autoriser l'exécution des scripts pour la session en cours :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

> ⚠️ `-Scope Process` ne vaut **que pour la fenêtre ouverte**. La commande est à retaper à chaque nouvelle console, y compris après réinstallation. C'est volontaire : on ne désactive pas durablement une protection pour la commodité d'une intervention.

> ⚠️ Ne jamais déposer les outils sur le Bureau ou dans les Documents. Ils seraient inventoriés comme des données utilisateur, sauvegardés, restaurés, et fausseraient la comparaison finale.

**Preuve à conserver :** aucune.

---

## Étape 1 — Relever l'état initial

**Objectif :** disposer d'un point de référence opposable. On ne peut démontrer un retour à l'identique que si l'état de départ a été documenté.

```powershell
winver
hostname
```

**Preuve à conserver :** capture montrant l'édition, la version, le build et le nom de la machine.

---

## Étape 2 — Relever la configuration non-fichier

**Objectif :** capturer tout ce qui devra être **recréé** et non restauré.

⚠️ **Étape impérativement antérieure à l'effacement.** Après formatage, ces informations n'existent plus nulle part.

```powershell
$f = "C:\Outils\configuration-poste.txt"
"=== NOM DU POSTE ===" | Out-File $f
hostname | Out-File $f -Append
"`n=== SYSTEME ===" | Out-File $f -Append
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture | Format-List | Out-File $f -Append
"`n=== COMPTES LOCAUX ===" | Out-File $f -Append
Get-LocalUser | Format-Table Name,Enabled,Description -AutoSize | Out-File $f -Append
"`n=== GROUPE ADMINISTRATEURS ===" | Out-File $f -Append
net localgroup Administrateurs | Out-File $f -Append
"`n=== CONFIGURATION RESEAU ===" | Out-File $f -Append
Get-NetIPConfiguration | Out-File $f -Append
"`n=== IMPRIMANTES ===" | Out-File $f -Append
Get-Printer | Format-Table Name,DriverName,PortName -AutoSize | Out-File $f -Append
"`n=== LOGICIELS INSTALLES ===" | Out-File $f -Append
Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher | Sort-Object DisplayName | Format-Table -AutoSize | Out-File $f -Append
```

**À vérifier dans le relevé :**

| Point | Question à se poser |
|---|---|
| Adresse IP | Est-elle dans la plage DHCP, ou s'agit-il d'une adresse fixe à ressaisir ? |
| Comptes | Lesquels sont actifs ? Lesquels sont administrateurs ? |
| Imprimantes | Y a-t-il des imprimantes réelles, ou seulement les imprimantes virtuelles de Windows ? |
| Logiciels | Lesquels sont des logiciels métier, lesquels sont fournis par le système ? |

**Preuve à conserver :** le fichier `configuration-poste.txt` lui-même, plus une capture lisible (zoom 100 % ; faire deux captures plutôt qu'une illisible).

---

## Étape 3 — Préparer le support de sauvegarde

**Objectif :** un support identifiable et fiable.

1. Connecter le support.
2. `diskmgmt.msc` → si le disque est « Non initialisé », l'initialiser en **GPT**.
3. Clic droit sur l'espace non alloué → `Nouveau volume simple`.

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Taille | maximum | un support de sauvegarde n'a aucune raison d'être découpé |
| Système de fichiers | **NTFS** | pas de limite à 4 Go par fichier, conservation des permissions |
| Nom de volume | **`SAUVEGARDE`** | c'est ce nom qui permettra de l'identifier à l'écran de partitionnement |
| Formatage rapide | coché | le support est neuf |
| Compression NTFS | **décochée** | ralentit chaque accès pour un gain nul, et ajoute une couche logicielle sur un support dont on attend uniquement de la fiabilité |

⚠️ **Vérifier l'orthographe du nom de volume.** Il apparaîtra sur toutes les captures suivantes et servira à identifier le disque au moment le plus critique de l'intervention.

**Preuve à conserver :** capture de la Gestion des disques montrant le volume sain avec son nom et sa lettre.

---

## Étape 4 — Inventorier les données avec empreintes

**Objectif :** produire l'inventaire de référence. C'est la pièce centrale de toute la procédure.

```powershell
cd C:\Outils
.\p3-inventaire.ps1 -Racine "$env:USERPROFILE" -Sortie "C:\Outils\inventaire-01-origine.csv"
```

Le script parcourt `Documents`, `Desktop` et `Pictures`, calcule l'empreinte SHA-256 de chaque fichier et enregistre :

| Colonne | Contenu |
|---|---|
| `CheminRelatif` | chemin **par rapport au dossier de départ** |
| `TailleOctets` | taille |
| `DateModification` | date de dernière modification |
| `SHA256` | empreinte, 64 caractères hexadécimaux |

> **Pourquoi un chemin relatif.** Le même fichier existera successivement sur le disque système, sur le support de sauvegarde, puis de nouveau sur le disque système. Avec des chemins absolus, les trois inventaires seraient incomparables. Ce n'est pas une précaution théorique : **la lettre du support change fréquemment après une réinstallation**, et un inventaire en chemins absolus signalerait alors 100 % d'écarts sur des fichiers parfaitement intacts.

**Si le poste contient d'autres dossiers métier** (`D:\Travail`, un dossier à la racine…), ajouter le paramètre :

```powershell
.\p3-inventaire.ps1 -Racine "C:\" -Sortie "C:\Outils\inventaire-01-metier.csv" -Dossiers "Travail","Archives"
```

**Preuves à conserver :** capture de l'exécution (récapitulatif + aperçu des empreintes) et capture du CSV ouvert.

---

## Étape 5 — Sauvegarder

**Objectif :** copier les données sans altération, avec un périmètre identique à celui de l'inventaire.

```powershell
robocopy "$env:USERPROFILE\Documents" "E:\Sauvegarde-<POSTE>\Documents" /E /COPY:DAT /XA:SH /R:2 /W:2
robocopy "$env:USERPROFILE\Desktop"   "E:\Sauvegarde-<POSTE>\Desktop"   /E /COPY:DAT /XA:SH /R:2 /W:2
robocopy "$env:USERPROFILE\Pictures"  "E:\Sauvegarde-<POSTE>\Pictures"  /E /COPY:DAT /XA:SH /R:2 /W:2
```

| Option | Effet | Pourquoi |
|---|---|---|
| `/E` | sous-dossiers inclus, même vides | conserve l'arborescence |
| `/COPY:DAT` | Données + Attributs + horodatages | les dates doivent survivre |
| `/XA:SH` | exclut Système et cachés | **reproduit exactement le périmètre de l'inventaire** |
| `/R:2 /W:2` | 2 tentatives, 2 s d'attente | par défaut `robocopy` réessaie un million de fois et bloque |

> Un code de retour `1` signifie « fichiers copiés avec succès ». Seul un code `≥ 8` indique une erreur réelle.

⚠️ **Ne jamais copier le profil entier.** `AppData` contient des dizaines de milliers de fichiers de cache et de fichiers verrouillés, qui ne sont pas des données utilisateur et ne se restaurent pas sur un autre système.

**Copier aussi les fichiers techniques**, qui disparaîtraient avec le disque système :

```powershell
New-Item -ItemType Directory -Force -Path "E:\_technique"
Copy-Item "C:\Outils\*" -Destination "E:\_technique" -Recurse -Force
```

⚠️ Placer ce dossier **à la racine du support**, jamais dans `E:\Sauvegarde-<POSTE>\`, sinon il reviendrait dans les données restaurées et fausserait la comparaison finale.

**Preuve à conserver :** capture du récapitulatif `robocopy` (0 ÉCHEC).

---

## Étape 6 — Vérifier l'intégrité de la sauvegarde

**Objectif :** établir que la copie est fidèle. **Aucun effacement n'est autorisé avant que cette étape ait rendu un verdict conforme.**

```powershell
.\p3-inventaire.ps1 -Racine "E:\Sauvegarde-<POSTE>" -Sortie "C:\Outils\inventaire-02-sauvegarde.csv"
.\p3-comparer.ps1 -Reference "C:\Outils\inventaire-01-origine.csv" -Controle "C:\Outils\inventaire-02-sauvegarde.csv"
```

Résultat attendu :

```
 VERDICT : N fichiers verifies, 0 ecart(s)
 INTEGRITE CONFIRMEE
```

**Si le verdict n'est pas conforme :**

| Diagnostic | Signification | Action |
|---|---|---|
| `[ALTERE]` | le fichier existe des deux côtés, contenu différent | recopier ce fichier, relancer la vérification |
| `[MANQUANT]` | présent à l'origine, absent de la copie | vérifier le périmètre `robocopy`, recopier |
| `[EN TROP]` | présent dans la copie, absent à l'origine | vérifier que les options d'exclusion sont identiques des deux côtés |

⚠️ **Ne pas passer à l'étape suivante tant que le verdict n'est pas `0 ecart`.** C'est le point de non-retour de la procédure.

**Preuve à conserver :** capture montrant **les empreintes comparées et le verdict sur la même image**. Un verdict seul ne prouve pas ce qui a été comparé.

---

## Étape 7 — Protéger le support avant l'effacement

**Objectif :** rendre l'étape destructrice réversible.

**Cas normal :** déconnecter physiquement le support (débrancher le disque USB, ou retirer le disque virtuel des paramètres de la machine).

**Si le support ne peut pas être déconnecté** — par exemple sur une machine virtuelle chiffrée, où le chiffrement imposé par le vTPM verrouille la modification du matériel :

1. Identifier le fichier du disque virtuel (visible dans les paramètres de la machine).
2. En **copier** (jamais déplacer) une version dans un dossier extérieur à celui de la machine virtuelle.
3. Documenter la contrainte et la mesure compensatoire.

> Le principe n'est pas « débrancher le câble », il est **« la sauvegarde ne doit pas se trouver au même endroit que l'opération risquée »**. Quand la mise en œuvre habituelle est impossible, c'est le principe qu'il faut satisfaire autrement — et l'écart doit être tracé.

**Preuve à conserver :** capture montrant la déconnexion, ou la copie à son nouvel emplacement.

---

## Étape 8 — Réinstaller

**Objectif :** un système propre, conforme à celui d'origine.

1. Monter le média d'installation, démarrer dessus (`Press any key…`, ou menu de démarrage).
2. **Édition : la même que celle relevée à l'étape 1.** Passer de Professionnel à Famille est une perte de fonctionnalités pour l'utilisateur — stratégies de sécurité locales, BitLocker, jonction au domaine.
3. Type d'installation : **Personnalisée**, jamais « Mise à niveau ». Une mise à niveau reconduit les résidus du système précédent.

### ⚠️ Écran de partitionnement — le point le plus dangereux

**Sous Windows en français, le libellé est une traduction fautive : « Partition 0 du disque 3 » signifie *disque 0, partition 3*.**

Avant de supprimer quoi que ce soit :

- identifier le disque système par sa **taille totale**
- identifier le support de sauvegarde par son **nom de volume** (`SAUVEGARDE`)
- ne supprimer que les partitions **du disque système**
- **relire la liste une fois de plus avant le premier clic**

Le résultat attendu est un espace non alloué de la taille du disque système, le support de sauvegarde restant visible et intact.

**Preuves à conserver :** capture **avant** suppression (état des deux disques) et capture **après** (système effacé, sauvegarde intacte). La seconde est la plus importante : elle établit les deux faits sur une seule image.

---

## Étape 9 — Reconfigurer

**Objectif :** rétablir ce qui a été relevé à l'étape 2.

1. **Compte utilisateur** — recréer le même nom.

   Sur Windows 11 24H2, l'assistant impose un compte Microsoft. Pour créer un compte local : `Maj` + `F10`, puis

   ```
   start ms-cxh:localonly
   ```

   > L'ancien contournement `oobe\bypassnro` a été retiré de la version 24H2.

2. **Nom de machine** — identique à l'origine :

   ```powershell
   Rename-Computer -NewName "<NOM-RELEVE>" -Restart
   ```

   > Nécessite une console **élevée** (clic droit sur Démarrer → `Terminal (administrateur)`). Appartenir au groupe Administrateurs ne suffit pas : le UAC n'accorde les droits qu'à la demande.

3. **Réseau** — si le relevé indiquait une adresse fixe, la ressaisir. Si l'adresse était dans la plage DHCP, ne rien faire.

4. **Imprimantes** — réinstaller celles relevées à l'étape 2, en ignorant les imprimantes virtuelles fournies par Windows.

5. **Retirer le média d'installation**, sinon son programme se relance automatiquement.

**Preuve à conserver :** capture avec `winver` et `hostname` visibles ensemble.

---

## Étape 10 — Restaurer

**Objectif :** ramener les données, avec le même périmètre qu'à la sauvegarde.

⚠️ **Vérifier d'abord la lettre du support.** Elle a très probablement changé :

```powershell
Get-Volume | Format-Table DriveLetter, FileSystemLabel, FileSystemType, Size -AutoSize
```

Puis, en adaptant la lettre :

```powershell
robocopy "<L>:\Sauvegarde-<POSTE>\Documents" "$env:USERPROFILE\Documents" /E /COPY:DAT /XA:SH /R:2 /W:2
robocopy "<L>:\Sauvegarde-<POSTE>\Desktop"   "$env:USERPROFILE\Desktop"   /E /COPY:DAT /XA:SH /R:2 /W:2
robocopy "<L>:\Sauvegarde-<POSTE>\Pictures"  "$env:USERPROFILE\Pictures"  /E /COPY:DAT /XA:SH /R:2 /W:2
```

Remettre également les outils en place :

```powershell
New-Item -ItemType Directory -Force -Path C:\Outils
Copy-Item "<L>:\_technique\*" -Destination "C:\Outils" -Recurse -Force
```

**Preuve à conserver :** capture du récapitulatif `robocopy` (0 ÉCHEC).

---

## Étape 11 — Vérifier l'intégrité de la restauration

**Objectif :** la démonstration finale. C'est l'étape qui distingue une migration d'un déplacement de fichiers.

```powershell
cd C:\Outils
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\p3-inventaire.ps1 -Racine "$env:USERPROFILE" -Sortie "C:\Outils\inventaire-03-restauration.csv"
.\p3-comparer.ps1 -Reference "C:\Outils\inventaire-01-origine.csv" -Controle "C:\Outils\inventaire-03-restauration.csv"
```

⚠️ **La référence est `inventaire-01-origine.csv`, jamais `inventaire-02-sauvegarde.csv`.** Comparer la restauration à la sauvegarde ne prouverait que la fidélité de la seconde copie. Ce qu'il faut établir, c'est la fidélité **à l'état d'avant l'effacement**.

Résultat attendu :

```
 VERDICT : N fichiers verifies, 0 ecart(s)
 INTEGRITE CONFIRMEE
```

**Preuve à conserver :** capture montrant les empreintes comparées **et** le verdict.

---

## Étape 12 — Contrôler l'usage et clore

**Objectif :** vérifier que l'utilisateur peut effectivement travailler. Une empreinte identique prouve que les octets sont les mêmes ; elle ne prouve pas que le fichier est accessible ni exploitable.

1. **Ouvrir un fichier restauré** et vérifier sa lisibilité.

2. **Reproduire le relevé de configuration** (commandes de l'étape 2, avec un nom de fichier différent), puis le confronter au relevé initial :

| Point | Attendu |
|---|---|
| Nom de machine | identique |
| Édition du système | identique (version supérieure) |
| Comptes | mêmes noms, même état |
| Réseau | même adressage, ou adresse fixe ressaisie |
| Imprimantes | mêmes imprimantes réelles |
| Logiciels | mêmes logiciels métier |

> Des différences sont normales sur les **composants système** : certains outils de maintenance propres à l'ancienne version n'existent plus dans la nouvelle. Les identifier et les justifier plutôt que les passer sous silence.

3. **Prendre un instantané** ou un point de restauration de l'état final.

4. **Archiver les pièces :** les trois inventaires CSV, les deux rapports de comparaison horodatés, et les deux relevés de configuration.

**Preuves à conserver :** capture du fichier ouvert, capture du relevé de configuration final.

---

## Liste de contrôle

```
PRÉPARATION
[ ] Outils déposés hors du profil utilisateur (C:\Outils)
[ ] Politique d'exécution levée pour la session
[ ] État initial relevé (édition, version, build, nom)
[ ] Configuration non-fichier relevée et sauvegardée
[ ] Support de sauvegarde formaté NTFS et nommé

SAUVEGARDE
[ ] Inventaire de référence produit (empreintes SHA-256)
[ ] Données copiées (robocopy, 0 ÉCHEC)
[ ] Fichiers techniques copiés à la racine du support
[ ] Inventaire de la sauvegarde produit
[ ] ►► VÉRIFICATION 1 : 0 écart ◄◄
[ ] Support déconnecté, ou copie placée hors de portée

RÉINSTALLATION
[ ] Édition identique à l'origine
[ ] Installation personnalisée (pas de mise à niveau)
[ ] ►► Partitions du DISQUE SYSTÈME uniquement supprimées ◄◄
[ ] Support de sauvegarde vérifié intact après suppression
[ ] Compte utilisateur recréé au même nom
[ ] Machine renommée à l'identique
[ ] Réseau et imprimantes reconfigurés
[ ] Média d'installation retiré

RESTAURATION
[ ] Lettre du support vérifiée (Get-Volume)
[ ] Données restaurées (robocopy, 0 ÉCHEC)
[ ] Inventaire post-restauration produit
[ ] ►► VÉRIFICATION 2 : 0 écart, par rapport à l'ORIGINE ◄◄
[ ] Un fichier ouvert et vérifié lisible
[ ] Relevé de configuration final confronté à l'initial
[ ] Instantané / point de restauration créé
[ ] Pièces archivées (3 CSV, 2 rapports, 2 relevés)
```

---

## Points de vigilance — résumé

| Situation | Piège | Parade |
|---|---|---|
| Écran de partitionnement | libellé français inversé ; disques multiples affichés | identifier par taille **et** nom de volume, relire avant de cliquer |
| Après réinstallation | la lettre du support a changé | `Get-Volume` avant toute commande |
| Inventaire | chemins absolus incomparables entre disques | chemins relatifs |
| Copie | périmètre différent de celui de l'inventaire | mêmes exclusions des deux côtés (`/XA:SH`) |
| Vérification finale | comparer à la sauvegarde au lieu de l'origine | référence = `inventaire-01-origine.csv` |
| Outils du technicien | inventoriés comme données utilisateur | toujours hors du profil |
| Nouvelle console PowerShell | politique d'exécution retombée | retaper `Set-ExecutionPolicy -Scope Process` |
| Renommage du poste | « Accès refusé » malgré des droits admin | console élevée (UAC) |
| Windows 11 24H2 | compte Microsoft imposé | `Maj`+`F10` → `start ms-cxh:localonly` |
| Fin d'intervention | le média d'installation relance le programme | retirer l'ISO / la clé USB |

---

*Procédure rédigée par P.G — PPE IT Essentials 187, classe E1B — 15 septembre 2026*
