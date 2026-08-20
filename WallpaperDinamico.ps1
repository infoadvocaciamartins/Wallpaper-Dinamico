# =====================================================================
# PARTE 1: O ENTREGADOR PREPARA O TERRENO ----
# =====================================================================
$PastaDestino = "C:\ProgramData\AdvocaciaMartins"
if (!(Test-Path $PastaDestino)) { New-Item -ItemType Directory -Path $PastaDestino -Force | Out-Null }
$CaminhoScriptLocal = "$PastaDestino\RotacaoWallpaper.ps1"

# =====================================================================
# PARTE 2: O SCRIPT PRINCIPAL (QUE SERÁ SALVO NO PC)
# =====================================================================
$CodigoRotacao = @'
$ErrorActionPreference = "SilentlyContinue"

# Não roda aos finais de semana
$DayOfWeek = (Get-Date).DayOfWeek
if ($DayOfWeek -eq 'Saturday' -or $DayOfWeek -eq 'Sunday') { exit 0 }

# --- COLOQUE SEUS LINKS RAW DO GITHUB AQUI ---
$Urls = @(
    "https://raw.githubusercontent.com/infoadvocaciamartins/Wallpaper-Dinamico/refs/heads/main/1.jpeg",
    "https://raw.githubusercontent.com/infoadvocaciamartins/Wallpaper-Dinamico/refs/heads/main/2.jpeg",
    "https://raw.githubusercontent.com/infoadvocaciamartins/Wallpaper-Dinamico/refs/heads/main/3.jpeg",
    "https://raw.githubusercontent.com/infoadvocaciamartins/Wallpaper-Dinamico/refs/heads/main/4.jpeg"
)

$PastaWallpapers = "$env:LOCALAPPDATA\AdvocaciaMartins\Wallpapers"
if (!(Test-Path $PastaWallpapers)) { New-Item -ItemType Directory -Path $PastaWallpapers -Force | Out-Null }

# Regra: Só troca uma vez por dia
$Hoje = (Get-Date).Format("yyyyMMdd")
if (Get-ChildItem -Path $PastaWallpapers -Filter "Wallpaper_$Hoje*") { exit 0 }

# Regra: Não repete a imagem atual
$regPath = "HKCU:\Control Panel\Desktop"
$CurrentWallpaper = (Get-ItemProperty -Path $regPath -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
$AvailableUrls = $Urls | Where-Object { $CurrentWallpaper -notmatch ([uri]$_).Segments[-1] }
$SelectedUrl = $AvailableUrls | Get-Random

# Baixa a nova imagem e apaga as antigas (baseado no seu código original)
$NomeArquivoGitHub = ([uri]$SelectedUrl).Segments[-1]
$destFile = "$PastaWallpapers\Wallpaper_$($Hoje)_$NomeArquivoGitHub"

try {
    Get-ChildItem -Path $PastaWallpapers -Filter "Wallpaper_*" | Remove-Item -Force
    Invoke-WebRequest -Uri $SelectedUrl -OutFile $destFile -ErrorAction Stop
} catch { exit 1 }

# --- APLICA NA ÁREA DE TRABALHO ---
Set-ItemProperty -Path $regPath -Name Wallpaper -Value $destFile
$code = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
if (-not ([System.Management.Automation.PSTypeName]'Wallpaper').Type) { Add-Type -TypeDefinition $code }
[Wallpaper]::SystemParametersInfo(0x0014, 0, $destFile, 3)

# --- APLICA NA TELA DE BLOQUEIO (Via Registo HKLM) ---
$RegPathLockScreen = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
if (!(Test-Path $RegPathLockScreen)) { New-Item -Path $RegPathLockScreen -Force | Out-Null }
Set-ItemProperty -Path $RegPathLockScreen -Name "LockScreenImage" -Value $destFile
'@

# Salva o script acima dentro do disco C: do computador
$CodigoRotacao | Out-File -FilePath $CaminhoScriptLocal -Encoding UTF8 -Force

# =====================================================================
# PARTE 3: O ENTREGADOR CRIA O "DESPERTADOR" NO WINDOWS
# =====================================================================

$NomeTarefa = "AdvocaciaMartins_RotacaoWallpaper"
$CaminhoScriptLocal = "C:\ProgramData\AdvocaciaMartins\RotacaoWallpaper.ps1"

$Acao = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$CaminhoScriptLocal`""
$Gatilho1 = New-ScheduledTaskTrigger -AtLogOn
$Gatilho2 = New-ScheduledTaskTrigger -Daily -At 8:00AM

# IMPORTANTE: A permissão foi alterada para 'Highest' (Privilégio de Administrador) para poder gravar no Registo HKLM
$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Highest

Register-ScheduledTask -TaskName $NomeTarefa -Action $Acao -Trigger @($Gatilho1, $Gatilho2) -Principal $Principal -Force