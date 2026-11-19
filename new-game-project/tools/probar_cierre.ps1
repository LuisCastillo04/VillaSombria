# Prueba real del cierre de la ventana: abre el juego con ventana, espera a que juegue y
# guarde, lo cierra como lo haría el jugador y comprueba las ranuras en otro proceso.
# Uso:  powershell -File tools\probar_cierre.ps1 [-Metodo X|AltF4]
#   X      envía a la ventana del juego el mensaje de cierre de Windows (WM_CLOSE), el mismo
#          que produce el botón X.
#   AltF4  envía a la ventana del juego la pulsación de Alt + F4 (WM_SYSKEYDOWN de F4 con
#          Alt), que Windows convierte en la orden de cierre como con el teclado real.
# Los mensajes van dirigidos a la ventana del proceso del juego, nunca a la que esté en primer
# plano. Usa user://pruebas_guardado/cierre: nunca toca las partidas del jugador.
param([ValidateSet('X', 'AltF4')][string]$Metodo = 'X')

$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = 'D:\Program Files (x86)\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
}
if (-not (Test-Path $godot)) {
    Write-Error "No se encuentra Godot en '$godot'. Define la variable GODOT_BIN."
    exit 2
}
$proyecto = Split-Path -Parent $PSScriptRoot
$registro = Join-Path ([IO.Path]::GetTempPath()) "villa_sombria_cierre_$PID.log"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class VentanaJuego {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@

$argumentos = @('--path', "`"$proyecto`"", '--resolution', '960x540', 'res://tests/persistencia/cierre.tscn', '--', '--fase=jugar')
$juego = Start-Process -FilePath $godot -ArgumentList $argumentos -PassThru -RedirectStandardOutput $registro
# Leer el manejador ahora permite consultar después el código de salida.
$null = $juego.Handle

$limite = (Get-Date).AddSeconds(90)
while (-not ((Test-Path $registro) -and (Select-String -Path $registro -Pattern 'LISTO para cerrar' -Quiet))) {
    if ($juego.HasExited -or (Get-Date) -gt $limite) {
        Write-Host 'FALLO: el juego no llegó a estar listo.'
        if (Test-Path $registro) { Get-Content $registro | Select-String 'FALLO|ERROR' }
        if (-not $juego.HasExited) { Stop-Process -Id $juego.Id }
        exit 1
    }
    Start-Sleep -Milliseconds 300
}
Start-Sleep -Milliseconds 500
$juego.Refresh()
$ventana = $juego.MainWindowHandle
if ($ventana -eq [IntPtr]::Zero) {
    Write-Host 'FALLO: no se encontró la ventana del juego.'
    Stop-Process -Id $juego.Id
    exit 1
}

if ($Metodo -eq 'X') {
    Write-Host 'Cerrando la ventana del juego con WM_CLOSE (botón X)...'
    $null = [VentanaJuego]::PostMessage($ventana, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
} else {
    Write-Host 'Enviando Alt + F4 a la ventana del juego...'
    # lParam: una repetición, código de exploración de F4 (0x3E) y el bit 29, «Alt pulsada».
    $abajo = [IntPtr](0x20000001 -bor (0x3E -shl 16))
    $arriba = [IntPtr]([int64]0xE0000001 -bor (0x3E -shl 16))
    $null = [VentanaJuego]::PostMessage($ventana, 0x0104, [IntPtr]0x73, $abajo)
    $null = [VentanaJuego]::PostMessage($ventana, 0x0105, [IntPtr]0x73, $arriba)
}

if (-not $juego.WaitForExit(30000)) {
    Write-Host 'FALLO: el juego no se cerró tras la petición de cierre.'
    Stop-Process -Id $juego.Id
    exit 1
}
$juego.WaitForExit()
Write-Host "El juego se cerró (código $($juego.ExitCode))."

$salida = & $godot --headless --path $proyecto 'res://tests/persistencia/cierre.tscn' -- '--fase=comprobar' 2>&1 | Out-String
$salida -split "`n" | Where-Object { $_ -match '^(FALLO|CIERRE)' } | ForEach-Object { Write-Host $_ }
Remove-Item $registro -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { exit 1 }
