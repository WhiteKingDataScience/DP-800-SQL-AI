# PowerShell script to publish DP-800-SQL-AI to GitHub
Write-Host "=== Publishing DP-800-SQL-AI to GitHub ===" -ForegroundColor Cyan

# Set location
Set-Location "d:\SQL\DP-800 Microsoft SQL Server AI Developer"

# Remove existing remote if any and set new origin
git remote remove origin 2>$null
git remote add origin https://github.com/WhiteKingDataScience/DP-800-SQL-AI.git

# Stage all files including README.md and .gitignore
git add .

# Commit changes
git commit -m "Initial commit: DP-800 Microsoft SQL Server AI Developer codebase, guides, and T-SQL scripts"

# Rename branch to main
git branch -M main

# Push to GitHub
Write-Host "Pushing to https://github.com/WhiteKingDataScience/DP-800-SQL-AI.git..." -ForegroundColor Yellow
git push -u origin main

Write-Host "=== Successfully Published to GitHub! ===" -ForegroundColor Green
