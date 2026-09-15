<#
================================================================================
 Projet 3 - Migration et sauvegarde d'un poste existant
 INVENTAIRE DES DONNEES AVEC EMPREINTES SHA-256
 P.G - PPE IT Essentials 187 - Classe E1B

--------------------------------------------------------------------------------
 A QUOI SERT CE SCRIPT
--------------------------------------------------------------------------------
 Il parcourt les dossiers de donnees d'un utilisateur et produit un fichier CSV
 qui contient, pour chaque fichier trouve :
   - son chemin relatif (par rapport au dossier de depart)
   - sa taille en octets
   - sa date de derniere modification
   - son empreinte SHA-256

 Une EMPREINTE (ou "hash") est une signature de 64 caracteres calculee a partir
 du contenu du fichier. Deux proprietes la rendent utile :
   - le meme contenu donne TOUJOURS la meme empreinte
   - changer UN SEUL OCTET change completement l'empreinte

 C'est donc la preuve qu'un fichier copie est bien identique a l'original.
 Comparer les tailles ne suffit pas : un fichier corrompu pendant une copie
 garde souvent exactement la meme taille.

--------------------------------------------------------------------------------
 POURQUOI UN CHEMIN *RELATIF* ET PAS LE CHEMIN COMPLET
--------------------------------------------------------------------------------
 Le meme fichier va exister a trois endroits differents au cours de la migration :
   C:\Users\tech.pg\Documents\rapport.txt        (origine)
   E:\Sauvegarde-PC01-PG\Documents\rapport.txt   (sauvegarde)
   C:\Users\tech.pg\Documents\rapport.txt        (apres restauration)

 Si on enregistrait le chemin complet, les inventaires seraient incomparables.
 En enregistrant "Documents\rapport.txt" par rapport au dossier de depart,
 les trois inventaires deviennent directement comparables ligne a ligne.

--------------------------------------------------------------------------------
 UTILISATION
--------------------------------------------------------------------------------
 Ouvrir PowerShell, puis autoriser les scripts pour cette fenetre uniquement :
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

 1) AVANT la sauvegarde - inventaire de reference sur le poste source :
     .\p3-inventaire.ps1 -Racine "$env:USERPROFILE" `
                         -Sortie "$env:USERPROFILE\Desktop\inventaire-01-origine.csv"

 2) APRES la copie - inventaire de la sauvegarde :
     .\p3-inventaire.ps1 -Racine "E:\Sauvegarde-PC01-PG" `
                         -Sortie "E:\inventaire-02-sauvegarde.csv"

 3) APRES la restauration - inventaire des donnees revenues sur le poste :
     .\p3-inventaire.ps1 -Racine "$env:USERPROFILE" `
                         -Sortie "$env:USERPROFILE\Desktop\inventaire-03-restauration.csv"

 Les trois CSV sont ensuite compares avec p3-comparer.ps1
================================================================================
#>

param(
    # Dossier de depart. Les chemins seront enregistres par rapport a celui-ci.
    [Parameter(Mandatory = $true)]
    [string]$Racine,

    # Fichier CSV a produire.
    [Parameter(Mandatory = $true)]
    [string]$Sortie,

    # Sous-dossiers a inventorier. Modifiable si le poste a d'autres dossiers metier.
    [string[]]$Dossiers = @('Documents', 'Desktop', 'Pictures')
)

$ErrorActionPreference = 'Stop'

# --- Verification du dossier de depart ----------------------------------------
if (-not (Test-Path -LiteralPath $Racine)) {
    Write-Host "ERREUR : le dossier '$Racine' n'existe pas." -ForegroundColor Red
    exit 1
}
$Racine = (Resolve-Path -LiteralPath $Racine).Path.TrimEnd('\')

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " INVENTAIRE AVEC EMPREINTES SHA-256" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Dossier de depart : $Racine"
Write-Host " Sous-dossiers     : $($Dossiers -join ', ')"
Write-Host " Fichier produit   : $Sortie"
Write-Host ""

# --- Collecte des fichiers ----------------------------------------------------
$fichiers = @()

foreach ($d in $Dossiers) {
    $cible = Join-Path $Racine $d

    if (-not (Test-Path -LiteralPath $cible)) {
        Write-Host "  [ignore] $d - dossier absent" -ForegroundColor DarkYellow
        continue
    }

    # Pas de -Force : on exclut volontairement les fichiers caches type desktop.ini,
    # qui sont regeneres par Windows et fausseraient la comparaison.
    $trouves = Get-ChildItem -LiteralPath $cible -Recurse -File -ErrorAction SilentlyContinue
    Write-Host "  [scan]   $d - $($trouves.Count) fichier(s)" -ForegroundColor DarkGray
    $fichiers += $trouves
}

if ($fichiers.Count -eq 0) {
    Write-Host ""
    Write-Host "Aucun fichier trouve. Inventaire non genere." -ForegroundColor Red
    exit 1
}

# --- Calcul des empreintes ----------------------------------------------------
Write-Host ""
Write-Host "--- Calcul des empreintes SHA-256 ---" -ForegroundColor Cyan

$lignes = @()
$i = 0

foreach ($f in $fichiers) {
    $i++
    Write-Progress -Activity "Calcul des empreintes SHA-256" `
                   -Status "$i / $($fichiers.Count) - $($f.Name)" `
                   -PercentComplete (($i / $fichiers.Count) * 100)

    try {
        $empreinte = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }
    catch {
        $empreinte = "ERREUR-LECTURE"
        Write-Host "  !! illisible : $($f.FullName)" -ForegroundColor Red
    }

    $lignes += [PSCustomObject]@{
        CheminRelatif    = $f.FullName.Substring($Racine.Length + 1)
        TailleOctets     = $f.Length
        DateModification = $f.LastWriteTime.ToString('dd.MM.yyyy HH:mm:ss')
        SHA256           = $empreinte
    }
}

Write-Progress -Activity "Calcul des empreintes SHA-256" -Completed

# --- Ecriture du CSV ----------------------------------------------------------
$dossierSortie = Split-Path -Parent $Sortie
if ($dossierSortie -and -not (Test-Path -LiteralPath $dossierSortie)) {
    New-Item -ItemType Directory -Force -Path $dossierSortie | Out-Null
}

# Delimiteur ';' : c'est le separateur attendu par Excel en configuration
# francaise. Avec une virgule, tout le CSV atterrirait dans une seule colonne.
$lignes | Sort-Object CheminRelatif |
    Export-Csv -LiteralPath $Sortie -NoTypeInformation -Encoding UTF8 -Delimiter ';'

# --- Recapitulatif ------------------------------------------------------------
$volume = ($lignes | Measure-Object -Property TailleOctets -Sum).Sum

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " INVENTAIRE TERMINE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Fichiers inventories : $($lignes.Count)"
Write-Host " Volume total         : $([math]::Round($volume / 1MB, 2)) Mo"
Write-Host " CSV genere           : $Sortie"
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

# Apercu des 5 premieres lignes, pour que la capture d'ecran montre
# de vraies empreintes et pas seulement un message de fin.
Write-Host "--- Apercu (5 premieres lignes) ---" -ForegroundColor Cyan
$lignes | Sort-Object CheminRelatif | Select-Object -First 5 |
    Format-Table CheminRelatif, TailleOctets, @{ Name = 'SHA256 (debut)'; Expression = { $_.SHA256.Substring(0, 24) + '...' } } -AutoSize
