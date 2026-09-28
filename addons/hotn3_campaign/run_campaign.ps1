param([string]$Godot = "godot")
$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
& $Godot --path $ProjectDir "res://addons/hotn3_campaign/CampaignRoot.tscn"
exit $LASTEXITCODE
