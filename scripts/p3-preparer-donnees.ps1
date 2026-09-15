<#
================================================================================
 Projet 3 - Migration et sauvegarde d'un poste existant
 Preparation des donnees utilisateur de test - PC01-PG
 P.G - PPE IT Essentials 187 - Classe E1B

 OBJET
   Le poste source ne contenait aucune donnee utilisateur. Ce script
   reconstitue un profil realiste : documents de travail, sous-dossiers
   metier, et fichiers binaires (photos simulees).

   Les fichiers binaires sont essentiels : une verification d'integrite
   qui ne porterait que sur du texte ne demontrerait rien. Les empreintes
   SHA-256 s'appliquent a n'importe quel type de fichier, et c'est
   justement sur les binaires qu'une corruption de copie passe inapercue.

 UTILISATION
   PowerShell (pas besoin d'etre administrateur, les fichiers sont crees
   dans le profil de l'utilisateur courant) :
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
     .\p3-preparer-donnees.ps1
================================================================================
#>

$base = [Environment]::GetFolderPath('UserProfile')

Write-Host "`n=== Preparation des donnees utilisateur ===" -ForegroundColor Cyan
Write-Host "Profil cible : $base" -ForegroundColor DarkGray

# --- Arborescence ---------------------------------------------------------
$dossiers = @(
    "$base\Documents\Rapports",
    "$base\Documents\Contrats",
    "$base\Documents\Projet-Reseau",
    "$base\Desktop\A-traiter",
    "$base\Pictures\Photos-Interventions"
)

foreach ($d in $dossiers) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Write-Host "  dossier : $d" -ForegroundColor DarkGray
}

# --- Documents texte ------------------------------------------------------
$textes = @{
    "$base\Documents\Rapports\rapport-annuel-2026.txt" = @"
RAPPORT ANNUEL 2026
===================
Synthese des interventions realisees sur le parc informatique.
Nombre de postes suivis : 24
Incidents traites : 137
Temps moyen de resolution : 2h15
"@

    "$base\Documents\Rapports\notes-reunion-septembre.txt" = @"
NOTES DE REUNION - 03.09.2026
=============================
- Migration Windows 10 vers Windows 11 a planifier
- Budget materiel a valider avant fin octobre
- Formation utilisateurs prevue en novembre
"@

    "$base\Documents\Contrats\contrat-maintenance-2026.txt" = @"
CONTRAT DE MAINTENANCE INFORMATIQUE
====================================
Duree : 12 mois reconductibles
Perimetre : postes de travail, imprimantes, reseau local
Delai d'intervention : 4 heures ouvrees
"@

    "$base\Documents\Projet-Reseau\plan-adressage.txt" = @"
PLAN D'ADRESSAGE - RESEAU LOCAL
================================
192.168.190.1  - .9    : equipements reseau
192.168.190.10 - .99   : adresses fixes (serveurs, imprimantes)
192.168.190.128 - .254 : plage DHCP
"@

    "$base\Documents\Projet-Reseau\materiel-commande.csv" = @"
Reference;Designation;Quantite;Prix unitaire
SW-24P;Switch 24 ports gigabit;2;340.00
AP-WIFI6;Point d acces Wi-Fi 6;4;185.00
CABLE-CAT6;Cable Cat6 - 305m;1;210.00
"@

    "$base\Desktop\A-traiter\todo.txt" = @"
A TRAITER
=========
[ ] Sauvegarder le poste avant migration
[ ] Verifier la compatibilite Windows 11
[ ] Commander les licences manquantes
"@
}

Write-Host "`n--- Documents ---" -ForegroundColor Cyan
foreach ($fichier in $textes.Keys) {
    $textes[$fichier] | Out-File -FilePath $fichier -Encoding UTF8
    Write-Host "  $([IO.Path]::GetFileName($fichier))" -ForegroundColor Green
}

# --- Fichiers binaires (photos simulees) ----------------------------------
Write-Host "`n--- Fichiers binaires ---" -ForegroundColor Cyan

$photos = @{
    "$base\Pictures\Photos-Interventions\baie-brassage.jpg" = 480000
    "$base\Pictures\Photos-Interventions\salle-serveur.jpg"  = 620000
    "$base\Pictures\Photos-Interventions\schema-cablage.png" = 310000
}

$rnd = New-Object System.Random
foreach ($photo in $photos.Keys) {
    $taille = $photos[$photo]
    $octets = New-Object byte[] $taille
    $rnd.NextBytes($octets)
    [IO.File]::WriteAllBytes($photo, $octets)
    Write-Host "  $([IO.Path]::GetFileName($photo)) - $([math]::Round($taille/1KB)) Ko" -ForegroundColor Green
}

# --- Recapitulatif --------------------------------------------------------
$tous = Get-ChildItem -Path "$base\Documents","$base\Desktop","$base\Pictures" -Recurse -File -ErrorAction SilentlyContinue
$total = ($tous | Measure-Object -Property Length -Sum).Sum

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host " Donnees utilisateur preparees" -ForegroundColor Green
Write-Host " Fichiers : $($tous.Count)" -ForegroundColor Green
Write-Host " Volume   : $([math]::Round($total/1MB,2)) Mo" -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Cyan
Write-Host "CAPTURE a prendre : cette fenetre -> 02-donnees-utilisateur.png" -ForegroundColor Yellow
