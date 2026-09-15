<#
================================================================================
 Projet 3 - Migration et sauvegarde d'un poste existant
 COMPARAISON DE DEUX INVENTAIRES - VERIFICATION D'INTEGRITE
 P.G - PPE IT Essentials 187 - Classe E1B

--------------------------------------------------------------------------------
 A QUOI SERT CE SCRIPT
--------------------------------------------------------------------------------
 Il confronte deux fichiers CSV produits par p3-inventaire.ps1 et rend un
 verdict explicite : les fichiers sont-ils identiques, oui ou non.

 La comparaison se fait sur le CHEMIN RELATIF (la cle) et sur l'EMPREINTE
 SHA-256 (le contenu). Quatre cas sont distingues :

   IDENTIQUE  le fichier existe des deux cotes et son empreinte est la meme
   ALTERE     le fichier existe des deux cotes mais son empreinte differe
              -> le contenu a change, meme si le nom et la taille sont egaux
   MANQUANT   present dans l'inventaire de reference, absent du controle
              -> un fichier n'a pas ete copie ou pas restaure
   EN TROP    present dans le controle, absent de la reference
              -> un fichier s'est ajoute (souvent un fichier de travail oublie)

--------------------------------------------------------------------------------
 POURQUOI UN VERDICT ET PAS DEUX LISTES
--------------------------------------------------------------------------------
 Poser deux inventaires cote a cote ne prouve rien : personne ne compare
 11 empreintes de 64 caracteres a l'oeil. Ce qui fait preuve, c'est une
 conclusion calculee - "11 fichiers verifies, 0 ecart" - accompagnee du
 detail des ecarts s'il y en a.

 C'est aussi ce qui rend le controle utilisable en intervention : en cas
 d'ecart, le technicien sait immediatement QUEL fichier reprendre.

--------------------------------------------------------------------------------
 UTILISATION
--------------------------------------------------------------------------------
 Verification de la SAUVEGARDE (origine vs copie sur le disque externe) :
   .\p3-comparer.ps1 -Reference "C:\Outils\inventaire-01-origine.csv" `
                     -Controle  "C:\Outils\inventaire-02-sauvegarde.csv"

 Verification de la RESTAURATION (origine vs donnees revenues sur le poste) :
   .\p3-comparer.ps1 -Reference "C:\Outils\inventaire-01-origine.csv" `
                     -Controle  "C:\Outils\inventaire-03-restauration.csv"

 Un rapport texte est genere automatiquement a cote du fichier de controle.
================================================================================
#>

param(
    # Inventaire de reference : l'etat considere comme correct (l'origine).
    [Parameter(Mandatory = $true)]
    [string]$Reference,

    # Inventaire a controler : la copie ou les donnees restaurees.
    [Parameter(Mandatory = $true)]
    [string]$Controle,

    # Rapport texte a produire. Si vide, il est genere a cote du controle.
    [string]$Rapport = ''
)

$ErrorActionPreference = 'Stop'

foreach ($f in @($Reference, $Controle)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "ERREUR : fichier introuvable - $f" -ForegroundColor Red
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($Rapport)) {
    $Rapport = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $Controle)) `
                         ('rapport-comparaison-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
}

# --- Chargement des deux inventaires ------------------------------------------
$ref = @(Import-Csv -LiteralPath $Reference -Delimiter ';')
$ctl = @(Import-Csv -LiteralPath $Controle  -Delimiter ';')

# On indexe par chemin relatif : c'est la cle qui permet de rapprocher
# le meme fichier d'un inventaire a l'autre, quel que soit le disque.
$indexRef = @{}
foreach ($l in $ref) { $indexRef[$l.CheminRelatif] = $l }

$indexCtl = @{}
foreach ($l in $ctl) { $indexCtl[$l.CheminRelatif] = $l }

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " VERIFICATION D'INTEGRITE PAR EMPREINTES SHA-256" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Reference : $Reference   ($($ref.Count) fichiers)"
Write-Host " Controle  : $Controle   ($($ctl.Count) fichiers)"
Write-Host ""

# --- Comparaison ---------------------------------------------------------------
$identiques = @()
$alteres    = @()
$manquants  = @()
$enTrop     = @()

foreach ($chemin in $indexRef.Keys) {
    if (-not $indexCtl.ContainsKey($chemin)) {
        $manquants += $chemin
        continue
    }

    if ($indexRef[$chemin].SHA256 -eq $indexCtl[$chemin].SHA256) {
        $identiques += $chemin
    }
    else {
        $alteres += [PSCustomObject]@{
            Chemin           = $chemin
            EmpreinteOrigine = $indexRef[$chemin].SHA256
            EmpreinteControle= $indexCtl[$chemin].SHA256
        }
    }
}

foreach ($chemin in $indexCtl.Keys) {
    if (-not $indexRef.ContainsKey($chemin)) { $enTrop += $chemin }
}

$ecarts = $alteres.Count + $manquants.Count + $enTrop.Count

# --- Detail --------------------------------------------------------------------
Write-Host "--- Detail par fichier ---" -ForegroundColor Cyan
foreach ($chemin in ($identiques | Sort-Object)) {
    Write-Host ("  [IDENTIQUE] " + $chemin) -ForegroundColor Green
}
foreach ($a in $alteres) {
    Write-Host ("  [ALTERE   ] " + $a.Chemin) -ForegroundColor Red
    Write-Host ("               origine  : " + $a.EmpreinteOrigine) -ForegroundColor DarkRed
    Write-Host ("               controle : " + $a.EmpreinteControle) -ForegroundColor DarkRed
}
foreach ($m in ($manquants | Sort-Object)) {
    Write-Host ("  [MANQUANT ] " + $m) -ForegroundColor Red
}
foreach ($e in ($enTrop | Sort-Object)) {
    Write-Host ("  [EN TROP  ] " + $e) -ForegroundColor Yellow
}

# --- Preuve : trois empreintes completes affichees cote a cote -----------------
# Sans cela, la capture d'ecran ne montrerait qu'un compteur. Le correcteur
# doit pouvoir constater que ce sont bien des empreintes qui ont ete comparees.
if ($identiques.Count -gt 0) {
    Write-Host ""
    Write-Host "--- Verification visuelle (3 premiers fichiers) ---" -ForegroundColor Cyan
    foreach ($chemin in ($identiques | Sort-Object | Select-Object -First 3)) {
        Write-Host ("  " + $chemin) -ForegroundColor White
        Write-Host ("    origine  : " + $indexRef[$chemin].SHA256) -ForegroundColor DarkGray
        Write-Host ("    controle : " + $indexCtl[$chemin].SHA256) -ForegroundColor DarkGray
    }
}

# --- Verdict --------------------------------------------------------------------
$couleur = if ($ecarts -eq 0) { 'Green' } else { 'Red' }
$verdict = if ($ecarts -eq 0) { 'INTEGRITE CONFIRMEE' } else { 'INTEGRITE NON CONFIRMEE' }

Write-Host ""
Write-Host "================================================================" -ForegroundColor $couleur
Write-Host " VERDICT : $($identiques.Count) fichiers verifies, $ecarts ecart(s)" -ForegroundColor $couleur
Write-Host " $verdict" -ForegroundColor $couleur
Write-Host "================================================================" -ForegroundColor $couleur
if ($ecarts -gt 0) {
    Write-Host " Alteres : $($alteres.Count)   Manquants : $($manquants.Count)   En trop : $($enTrop.Count)" -ForegroundColor Red
}
Write-Host ""

# --- Rapport texte ---------------------------------------------------------------
$lignesRapport = @()
$lignesRapport += '================================================================================'
$lignesRapport += 'RAPPORT DE VERIFICATION D INTEGRITE - EMPREINTES SHA-256'
$lignesRapport += '================================================================================'
$lignesRapport += "Date        : $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
$lignesRapport += "Poste       : $env:COMPUTERNAME"
$lignesRapport += "Technicien  : P.G"
$lignesRapport += "Reference   : $Reference ($($ref.Count) fichiers)"
$lignesRapport += "Controle    : $Controle ($($ctl.Count) fichiers)"
$lignesRapport += ''
$lignesRapport += "VERDICT     : $($identiques.Count) fichiers verifies, $ecarts ecart(s)"
$lignesRapport += "              $verdict"
$lignesRapport += ''
$lignesRapport += '--------------------------------------------------------------------------------'
$lignesRapport += 'DETAIL'
$lignesRapport += '--------------------------------------------------------------------------------'
foreach ($chemin in ($identiques | Sort-Object)) {
    $lignesRapport += "[IDENTIQUE] $chemin"
    $lignesRapport += "            $($indexRef[$chemin].SHA256)"
}
foreach ($a in $alteres) {
    $lignesRapport += "[ALTERE   ] $($a.Chemin)"
    $lignesRapport += "            origine  : $($a.EmpreinteOrigine)"
    $lignesRapport += "            controle : $($a.EmpreinteControle)"
}
foreach ($m in ($manquants | Sort-Object)) { $lignesRapport += "[MANQUANT ] $m" }
foreach ($e in ($enTrop    | Sort-Object)) { $lignesRapport += "[EN TROP  ] $e" }
$lignesRapport += '================================================================================'

$lignesRapport | Out-File -LiteralPath $Rapport -Encoding UTF8

Write-Host "Rapport ecrit : $Rapport" -ForegroundColor Cyan
Write-Host ""

# Code de sortie exploitable : 0 = conforme, 1 = ecart detecte.
# Permet d'enchainer ce script dans une procedure automatisee.
if ($ecarts -eq 0) { exit 0 } else { exit 1 }
