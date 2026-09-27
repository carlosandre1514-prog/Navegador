# Gera o projeto Flutter completo (com as pastas nativas do Android) e aplica
# o código do navegador por cima. Rode no PowerShell:  .\setup.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter não encontrado no PATH. Instale em https://docs.flutter.dev/get-started/install"
  exit 1
}

$dest = "navegador_hibrido"
if (Test-Path $dest) {
  Write-Host "A pasta '$dest' já existe. Apague ou renomeie e rode de novo."
  exit 1
}

flutter create --org com.meunavegador --project-name navegador_hibrido --platforms=android $dest

# Copia o código do navegador por cima do projeto gerado
Copy-Item -Path "fonte\*" -Destination $dest -Recurse -Force
Remove-Item "$dest\test\widget_test.dart" -ErrorAction SilentlyContinue

# Firebase exige minSdk 23 ou maior (mantém o valor do Flutter se já for maior)
$kts = "$dest\android\app\build.gradle.kts"
if (Test-Path $kts) {
  (Get-Content $kts) -replace 'minSdk = flutter\.minSdkVersion', 'minSdk = maxOf(23, flutter.minSdkVersion)' | Set-Content $kts
}
$gr = "$dest\android\app\build.gradle"
if (Test-Path $gr) {
  (Get-Content $gr) `
    -replace 'minSdkVersion flutter\.minSdkVersion', 'minSdkVersion Math.max(23, flutter.minSdkVersion)' `
    -replace 'minSdk = flutter\.minSdkVersion', 'minSdk = Math.max(23, flutter.minSdkVersion)' | Set-Content $gr
}

Set-Location $dest
flutter pub get

Write-Host ""
Write-Host "Pronto! Projeto em: $(Get-Location)"
Write-Host "Próximos passos: leia o README.md (configurar Firebase e rodar)."
