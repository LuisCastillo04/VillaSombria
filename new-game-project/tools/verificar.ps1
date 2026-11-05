# Verificación completa del proyecto desde la terminal.
# Uso:  powershell -File tools\verificar.ps1
# Define GODOT_BIN si Godot no está en la ruta de Steam por defecto.
param([switch]$SinPruebas)

$ErrorActionPreference = 'Continue'
$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = 'D:\Program Files (x86)\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
}
if (-not (Test-Path $godot)) {
    Write-Error "No se encuentra Godot en '$godot'. Define la variable GODOT_BIN."
    exit 2
}
$proyecto = Split-Path -Parent $PSScriptRoot
$fallos = 0

function Invoke-Paso([string]$titulo, [string[]]$argumentos) {
    Write-Host "== $titulo =="
    $salida = & $godot @argumentos 2>&1 | Out-String
    $codigo = $LASTEXITCODE
    $errores = $salida -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|ERROR:|Failed to load|FALLO' }
    $salida -split "`n" | Where-Object { $_ -match '^\s*(OK|PRUEBAS|RESUMEN|FALLO)' } | ForEach-Object { Write-Host $_ }
    if ($errores) { $errores | ForEach-Object { Write-Host $_ } }
    if ($codigo -ne 0 -or $errores) {
        Write-Host "   -> FALLÓ (código $codigo)"
        $script:fallos++
    } else {
        Write-Host "   -> correcto"
    }
}

Invoke-Paso 'Importación' @('--headless', '--path', $proyecto, '--import')
Invoke-Paso 'Arranque de la escena principal' @('--headless', '--path', $proyecto, '--quit-after', '5')
if (-not $SinPruebas -and (Test-Path (Join-Path $proyecto 'tests\test_runner.tscn'))) {
    Invoke-Paso 'Pruebas automatizadas' @('--headless', '--path', $proyecto, 'res://tests/test_runner.tscn')
}

if ($fallos -gt 0) { Write-Host "RESUMEN: $fallos paso(s) con fallos"; exit 1 }
Write-Host 'RESUMEN: todo correcto'
