# Re-copy curated MZ DLC assets into this repo. Run from repo root on the Windows machine.
$ErrorActionPreference = "Stop"
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -ErrorAction SilentlyContinue
if (-not $repo) { $repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }
# When script lives in tools/, parent is repo
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$dlc = "D:\SteamLibrary\steamapps\common\RPG Maker MZ\dlc"
Write-Host "Repo=$repo"
# Effekseer curated (same list as initial import)
$efxDst = Join-Path $repo "assets\fx\effekseer"
$fxSrc = Join-Path $dlc "3D Particle Effect Pack\effects"
New-Item -ItemType Directory -Force -Path $efxDst,(Join-Path $efxDst Texture),(Join-Path $efxDst Material),(Join-Path $efxDst Model) | Out-Null
$names = Get-Content (Join-Path $efxDst "index.json") -Raw | ConvertFrom-Json | Select-Object -ExpandProperty curated
foreach ($n in $names) {
  $f = Join-Path $fxSrc "$n.efkefc"
  if (Test-Path $f) { Copy-Item $f $efxDst -Force }
}
Copy-Item (Join-Path $fxSrc "Texture\*") (Join-Path $efxDst "Texture") -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $fxSrc "Material\*") (Join-Path $efxDst "Material") -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $fxSrc "Model\*") (Join-Path $efxDst "Model") -Force -ErrorAction SilentlyContinue
$p2d = Join-Path $repo "assets\fx\particles2d"
New-Item -ItemType Directory -Force -Path $p2d | Out-Null
Get-ChildItem (Join-Path $dlc "TRP_ParticleMZ\materials\particles") -File | Copy-Item -Destination $p2d -Force
$bgmDst = Join-Path $repo "assets\audio\bgm"
New-Item -ItemType Directory -Force -Path $bgmDst,(Join-Path $bgmDst fantasy) | Out-Null
Copy-Item (Join-Path $dlc "TRP_ParticleMZ\sample_project_en\audio\bgm\*.ogg") $bgmDst -Force
Copy-Item (Join-Path $dlc "FantasyResourcePack\bgm\ogg\96kbps\*.ogg") (Join-Path $bgmDst fantasy) -Force
$sens = Join-Path $repo "assets\cast_sensitive"
New-Item -ItemType Directory -Force -Path $sens | Out-Null
Copy-Item (Join-Path $dlc "BasicResources\pictures\*") $sens -Force
Write-Host "Done."
