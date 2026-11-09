function Step($cmd) {
    Write-Host ">> $cmd" -ForegroundColor Cyan
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed: $cmd" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Set-Location $PSScriptRoot

Step "flutter clean"
Step "flutter pub get"
Step "dart run build_runner build --delete-conflicting-outputs"
Step "flutter run --profile -t lib/seed_main.dart --dart-define-from-file=config/dev.json"