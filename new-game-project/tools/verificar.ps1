# Verificación completa del proyecto desde la terminal.
# Uso:  powershell -File tools\verificar.ps1 [-ConVentana]
# -ConVentana añade lo que necesita una ventana: las imágenes reales de las ranuras y el
# cierre de la ventana con la X y con Alt + F4. Abre y cierra el juego varias veces.
# Define GODOT_BIN si Godot no está en la ruta de Steam por defecto.
param([switch]$SinPruebas, [switch]$ConVentana)

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
    $errores = $salida -split "`n" | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:|Failed to load|^FALLO' }
    $salida -split "`n" | Where-Object { $_ -cmatch '^RESUMEN' } | ForEach-Object { Write-Host $_ }
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
# Guarda en un proceso y carga en otro nuevo, como al cerrar y volver a abrir el juego.
if (-not $SinPruebas -and (Test-Path (Join-Path $proyecto 'tests\persistencia\reinicio.tscn'))) {
    Invoke-Paso 'Reinicio: guardar partida' @('--headless', '--path', $proyecto, 'res://tests/persistencia/reinicio.tscn', '--', '--fase=guardar')
    Invoke-Paso 'Reinicio: cargar en un proceso nuevo' @('--headless', '--path', $proyecto, 'res://tests/persistencia/reinicio.tscn', '--', '--fase=comprobar')
}
if ($ConVentana -and -not $SinPruebas) {
    Invoke-Paso 'Imágenes de las ranuras (con ventana)' @('--path', $proyecto, '--resolution', '1280x720', 'res://tests/visual/vista_previa.tscn')
    foreach ($metodo in @('X', 'AltF4')) {
        Write-Host "== Cierre de la ventana ($metodo) =="
        & powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar_cierre.ps1') -Metodo $metodo
        if ($LASTEXITCODE -ne 0) {
            Write-Host '   -> FALLÓ'
            $fallos++
        } else {
            Write-Host '   -> correcto'
        }
    }
}

if ($fallos -gt 0) { Write-Host "RESUMEN: $fallos paso(s) con fallos"; exit 1 }
Write-Host 'RESUMEN: todo correcto'
