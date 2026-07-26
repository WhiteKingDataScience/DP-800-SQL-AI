@echo off
title Publish DP-800-SQL-AI to GitHub
cd /d "d:\SQL\DP-800 Microsoft SQL Server AI Developer"

echo ========================================================
echo Publishing DP-800-SQL-AI to GitHub...
echo ========================================================

git remote remove origin 2>nul
git remote add origin https://github.com/WhiteKingDataScience/DP-800-SQL-AI.git

git add .
git commit -m "Initial commit: DP-800 Microsoft SQL Server AI Developer codebase, guides, and T-SQL scripts"
git branch -M main

echo.
echo Pushing to https://github.com/WhiteKingDataScience/DP-800-SQL-AI.git...
git push -u origin main

echo.
echo ========================================================
echo Process Finished!
echo ========================================================
pause
