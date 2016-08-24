#ps1_sysnative

$currentDir = $PSScriptRoot

function Prepare(){
    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | out-null
    $profileDir = Join-Path $currentDir "profile"
    $resourcesDir = Join-Path $currentDir "resources"
    $utilsDir = Join-Path $currentDir "utils"

    Write-Output "Unpacking files ..."
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory(".\resources.zip", $resourcesDir)
        Remove-Item -Force -Path ".\resources.zip" -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::ExtractToDirectory(".\deploy.zip", $currentDir)
        Remove-Item -Force -Path ".\deploy.zip" -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::ExtractToDirectory(".\utils.zip", $utilsDir)
        Remove-Item -Force -Path ".\utils.zip" -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "There was an error writing to the installation directory '${$currentDir}'.`r`nPlease make sure the folder and any of its child items are not in use, then run the installer again."
        exit 1;
    }

    Write-Output "Cleaning up zip content..."
}

Prepare
& (Join-Path $currentDir 'shell.ps1')
