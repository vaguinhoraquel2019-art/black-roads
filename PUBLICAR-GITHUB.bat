@echo off
chcp 65001 >nul
title Point da Aldeia - Publicar no GitHub Pages
setlocal enabledelayedexpansion

set "DIR=C:\Users\Wagner AMD\Downloads\point da aldeia"
set "USUARIO=vaguinhoraquel2019-art"
set "REPO=point-da-aldeia"

echo.
echo  ============================================
echo   POINT DA ALDEIA - GitHub Pages
echo  ============================================
echo.

cd /d "%DIR%"

:: Verifica Git
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  Git nao encontrado. Instalando...
    winget install --id Git.Git -e --source winget
    pause & exit /b 1
)
echo  Git OK!

:: Configura identidade
git config --global user.name "%USUARIO%"
git config --global user.email "%USUARIO%@users.noreply.github.com"

:: Remove remote antigo com erro e adiciona com credencial no link
git remote remove origin >nul 2>&1

echo.
echo  Digite seu token do GitHub quando solicitado.
echo  Para gerar um token acesse:
echo  https://github.com/settings/tokens/new
echo  - Marque a opcao "repo" e clique em "Generate token"
echo.
set /p TOKEN=  Cole seu token aqui e pressione Enter: 

if "!TOKEN!"=="" (
    echo  Token nao informado. Saindo.
    pause & exit /b 1
)

:: Adiciona remote com token embutido
git remote add origin https://!TOKEN!@github.com/%USUARIO%/%REPO%.git

:: Inicializa se necessario
if not exist "%DIR%\.git\HEAD" (
    git init
    git branch -M main
)

:: Garante branch main
git checkout -B main >nul 2>&1

:: Commit
git add -A
git commit -m "Atualizacao %date% %time:~0,8%" >nul 2>&1

:: Push
echo.
echo  Publicando...
git push -u origin main --force

if %errorlevel% equ 0 (
    echo.
    echo  ============================================
    echo   PUBLICADO COM SUCESSO!
    echo.
    echo   Acesse: https://%USUARIO%.github.io/%REPO%
    echo.
    echo   IMPORTANTE: Ative o GitHub Pages em:
    echo   github.com/%USUARIO%/%REPO%/settings/pages
    echo   Source: Deploy from branch - main - / (root)
    echo  ============================================
) else (
    echo.
    echo  Erro ao publicar. Verifique o token.
)

echo.
pause
