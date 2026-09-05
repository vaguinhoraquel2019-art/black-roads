@echo off
setlocal EnableDelayedExpansion

REM ── Reabrir em terminal persistente ao dar duplo clique ──────────────────────
if /i "%1" NEQ "--ja-aberto" (
    cmd /k ""%~f0" --ja-aberto"
    exit /b
)

echo.
echo  ============================================
echo   Black Roads - Configuracao do Repositorio
echo  ============================================
echo.

REM ════════════════════════════════════════════
REM  1. VERIFICA GIT
REM ════════════════════════════════════════════
where git >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Git nao encontrado.
    echo.
    echo  Instale em: https://git-scm.com/download/win
    echo  Depois execute este script novamente.
    echo.
    goto :fim
)
for /f "tokens=*" %%v in ('git --version') do echo [OK] %%v

REM ════════════════════════════════════════════
REM  2. INICIALIZA REPOSITORIO GIT
REM ════════════════════════════════════════════
echo.
if exist ".git\" (
    echo [OK] Repositorio Git ja existe.
) else (
    echo [INFO] Inicializando repositorio Git...
    git init -b main >nul 2>&1
    if errorlevel 1 (
        git init >nul 2>&1
        git checkout -b main >nul 2>&1
    )
    echo [OK] Repositorio inicializado.
)

REM ════════════════════════════════════════════
REM  3. CRIA .gitignore
REM ════════════════════════════════════════════
if not exist ".gitignore" (
    echo [INFO] Criando .gitignore...
    (
        echo .DS_Store
        echo Thumbs.db
        echo desktop.ini
        echo .vscode/
        echo .idea/
        echo *.log
        echo .env
        echo .env.local
    ) > .gitignore
    echo [OK] .gitignore criado.
) else (
    echo [OK] .gitignore ja existe.
)

REM ════════════════════════════════════════════
REM  4. CONFIGURA IDENTIDADE GIT
REM ════════════════════════════════════════════
for /f "delims=" %%e in ('git config user.email 2^>nul') do set GIT_EMAIL=%%e
if "!GIT_EMAIL!"=="" (
    echo.
    echo [INFO] Identidade do Git nao configurada.
    set /p GIT_NAME=  Seu nome (ex: Joao Silva): 
    set /p GIT_EMAIL=  Seu email (ex: joao@email.com): 
    git config user.name "!GIT_NAME!"
    git config user.email "!GIT_EMAIL!"
    echo [OK] Identidade configurada.
) else (
    echo [OK] Identidade Git: !GIT_EMAIL!
)

REM ════════════════════════════════════════════
REM  5. COMMIT INICIAL
REM ════════════════════════════════════════════
echo.
echo [INFO] Adicionando arquivos...
git add .
git diff --cached --quiet >nul 2>&1
if errorlevel 1 (
    git commit -m "feat: publica Black Roads"
    echo [OK] Commit criado.
) else (
    echo [OK] Nenhuma alteracao nova. Repositorio ja esta em dia.
)

REM ════════════════════════════════════════════
REM  6. CONECTAR AO GITHUB (OPCIONAL)
REM ════════════════════════════════════════════
echo.
echo ─────────────────────────────────────────────
echo  Para publicar no GitHub Pages voce precisa:
echo   1. Criar um repositorio em github.com/new
echo   2. Copiar a URL (ex: https://github.com/usuario/black-roads.git)
echo ─────────────────────────────────────────────
echo.
set /p RESP=  Voce ja tem a URL do repositorio? (s/n): 

if /i "!RESP!"=="s" (
    echo.
    set /p REPO_URL=  Cole a URL aqui: 
    echo.

    git remote get-url origin >nul 2>&1
    if errorlevel 1 (
        git remote add origin "!REPO_URL!"
    ) else (
        git remote set-url origin "!REPO_URL!"
    )

    echo [INFO] Enviando para o GitHub...
    git push -u origin main
    if errorlevel 1 (
        echo.
        echo [AVISO] Falha ao enviar. Verifique:
        echo  - Se a URL esta correta
        echo  - Se voce esta autenticado no GitHub
        echo    (use o publicar.bat para autenticar automaticamente)
    ) else (
        echo.
        echo [OK] Codigo enviado ao GitHub!
        echo.
        echo  Proximos passos para ativar o GitHub Pages:
        echo   1. Acesse o repositorio no GitHub
        echo   2. Va em Settings ^> Pages
        echo   3. Em Source, selecione "GitHub Actions"
        echo   4. O site vai no ar em ~2 minutos
    )
) else (
    echo.
    echo  Tudo configurado localmente!
    echo  Quando tiver a URL, rode o publicar.bat para enviar automaticamente.
)

:fim
echo.
echo  ============================================
echo   Concluido!
echo  ============================================
echo.
echo  Pressione qualquer tecla para fechar...
pause >nul
endlocal
