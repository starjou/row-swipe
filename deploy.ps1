$ErrorActionPreference = "Stop"
$godot = "D:\Program Files\Godot_v4.6.3\Godot_v4.6.3-stable_win64_console.exe"
$project = "D:\Work\Godot\row-swipe"

Write-Host "==> Exporting..." -ForegroundColor Cyan
& $godot --headless --export-release "Web" "build/index.html" --path $project

Write-Host "==> Pushing to itch.io..." -ForegroundColor Cyan
butler push "$project\build" starjou/row-swipe:html

Write-Host "==> Checking status..." -ForegroundColor Cyan
butler status starjou/row-swipe:html

Write-Host "==> Done!" -ForegroundColor Green
