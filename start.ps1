# HealthCare Companion : lance le backend (Spring Boot, base H2 en mémoire) et l'application (Flutter web),
# chacun dans sa propre fenêtre, puis ouvre http://localhost:5000 dans le navigateur.
#
# Utilisation : clic droit sur start.ps1 > « Exécuter avec PowerShell »
#           ou, dans un terminal :  powershell -ExecutionPolicy Bypass -File .\start.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# --- Java : JAVA_HOME existant, sinon le Java fourni par l'extension Java de VS Code
if (-not $env:JAVA_HOME -or -not (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    $jre = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter "redhat.java-*" -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem "$($_.FullName)\jre" -Directory -ErrorAction SilentlyContinue } |
        Where-Object { Test-Path "$($_.FullName)\bin\java.exe" } |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $jre) {
        Write-Host "Java introuvable : installez un JDK 17+ ou définissez JAVA_HOME." -ForegroundColor Red
        Read-Host "Entrée pour quitter"; exit 1
    }
    $env:JAVA_HOME = $jre.FullName
}
Write-Host "Java  : $env:JAVA_HOME"

# --- Maven : commande mvn du PATH, sinon la version téléchargée dans ~/.m2/wrapper
$mvn = (Get-Command mvn -ErrorAction SilentlyContinue).Source
if (-not $mvn) {
    $mvn = Get-ChildItem "$env:USERPROFILE\.m2\wrapper\dists" -Recurse -Filter mvn.cmd -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $mvn) {
    Write-Host "Maven introuvable : installez Maven (https://maven.apache.org) ou ajoutez-le au PATH." -ForegroundColor Red
    Read-Host "Entrée pour quitter"; exit 1
}
Write-Host "Maven : $mvn"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter introuvable : installez Flutter et ajoutez-le au PATH." -ForegroundColor Red
    Read-Host "Entrée pour quitter"; exit 1
}

# --- Libère les ports si une ancienne instance tourne encore
foreach ($port in 8081, 5000) {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}

# --- Fenêtre 1 : backend
$backend = @"
`$host.UI.RawUI.WindowTitle = 'HealthCare - Backend (8081)'
`$env:JAVA_HOME = '$env:JAVA_HOME'
`$env:JWT_SECRET = 'dGVzdC1zZWNyZXQta2V5LWZvci1oZWFsdGhjYXJlLWNvbXBhbmlvbi0yNTY='
`$env:ADMIN_PASSWORD = 'Admin12345'
`$env:DB_URL = 'jdbc:h2:mem:healthcare;MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1'
`$env:DB_USERNAME = 'sa'
`$env:DB_PASSWORD = ''
Set-Location '$root\backend'
& '$mvn' spring-boot:run '-Dspring-boot.run.profiles=dev' '-Dspring-boot.run.useTestClasspath=true'
"@
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $backend

# --- Attend que l'API réponde (premier démarrage : jusqu'à 3 minutes, le temps de télécharger les dépendances)
Write-Host "Démarrage du backend..." -NoNewline
$ready = $false
for ($i = 0; $i -lt 180; $i++) {
    Start-Sleep -Seconds 1
    if (Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue) { $ready = $true; break }
    if ($i % 5 -eq 0) { Write-Host "." -NoNewline }
}
Write-Host ""
if (-not $ready) {
    Write-Host "Le backend ne répond pas : regardez la fenêtre 'Backend' pour l'erreur." -ForegroundColor Yellow
}

# --- Fenêtre 2 : application Flutter web
$frontend = @"
`$host.UI.RawUI.WindowTitle = 'HealthCare - Application (5000)'
Set-Location '$root\frontend'
flutter pub get
flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8081
"@
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $frontend

Write-Host "Compilation de l'application..." -NoNewline
for ($i = 0; $i -lt 240; $i++) {
    Start-Sleep -Seconds 1
    if (Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue) { break }
    if ($i % 5 -eq 0) { Write-Host "." -NoNewline }
}
Write-Host ""
Start-Sleep -Seconds 5
Start-Process "http://localhost:5000"

Write-Host ""
Write-Host "Application : http://localhost:5000" -ForegroundColor Green
Write-Host "Comptes (mot de passe Demo12345) : patient@demo.tn, doctor@demo.tn, pharmacist@demo.tn, ambulance@demo.tn"
Write-Host "Admin : admin@healthcare.local / Admin12345"
Write-Host "Pour arrêter : fermez les deux fenêtres 'HealthCare'."
