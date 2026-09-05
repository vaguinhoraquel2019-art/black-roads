@echo off
setlocal EnableDelayedExpansion

REM ── Reabrir em terminal persistente ao dar duplo clique ──────────────────────
if /i "%1" NEQ "--ja-aberto" (
    cmd /k ""%~f0" --ja-aberto"
    exit /b
)

echo.
echo  ============================================
echo   Black Roads - Publicar no GitHub Pages
echo  ============================================
echo.

REM ════════════════════════════════════════════
REM  1. VERIFICA GIT E NODE
REM ════════════════════════════════════════════
where git >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Git nao encontrado.
    echo  Instale em: https://git-scm.com/download/win
    goto :fim
)
for /f "tokens=*" %%v in ('git --version') do echo [OK] %%v

where node >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Node.js nao encontrado.
    echo  Instale em: https://nodejs.org
    goto :fim
)
for /f "tokens=*" %%v in ('node --version') do echo [OK] Node.js %%v

REM ════════════════════════════════════════════
REM  2. DADOS DO USUARIO
REM ════════════════════════════════════════════
echo.
echo  Entre com os dados da sua conta do GitHub.
echo  (Se nao tiver conta, crie gratis em github.com)
echo.
set /p GH_USER=  Seu usuario do GitHub (ex: joaosilva): 
echo.
set /p GH_TOKEN=  Seu token do GitHub: 
echo.
echo.
echo  -- Como gerar o token (so precisa fazer uma vez): --
echo   1. Acesse: https://github.com/settings/tokens/new
echo   2. Em "Note" escreva: black-roads
echo   3. Em "Expiration" escolha: 90 days
echo   4. Marque a caixa: [x] repo  (primeira da lista)
echo   5. Clique em "Generate token" no final da pagina
echo   6. Copie e cole o token acima
echo  ----------------------------------------------------
echo.

if "!GH_USER!"=="" ( echo [ERRO] Usuario nao informado. & goto :fim )
if "!GH_TOKEN!"=="" ( echo [ERRO] Token nao informado. & goto :fim )

set /p REPO_NOME=  Nome do repositorio (ex: black-roads): 
if "!REPO_NOME!"=="" set REPO_NOME=black-roads
echo.

REM ════════════════════════════════════════════
REM  3. CRIA REPOSITORIO VIA API
REM ════════════════════════════════════════════
echo [INFO] Criando repositorio "!REPO_NOME!" no GitHub...

node "%~dp0publicar.js" "!GH_USER!" "!GH_TOKEN!" "!REPO_NOME!" "criar-repo" > "%TEMP%\br_result.txt" 2>&1
set /p API_RESULT=<"%TEMP%\br_result.txt"

REM Formato esperado: OK:criado:login:repo  ou  OK:existe:login:repo
for /f "tokens=1,2,3,4 delims=:" %%a in ("!API_RESULT!") do (
    set API_STATUS=%%a:%%b
    set GH_LOGIN=%%c
    set GH_REPO=%%d
)

if "!API_STATUS!"=="OK:criado" (
    echo [OK] Repositorio criado com sucesso!
) else if "!API_STATUS!"=="OK:existe" (
    echo [OK] Repositorio ja existe, usando o existente.
) else (
    echo [ERRO] !API_RESULT!
    goto :fim
)

REM Usa o login real retornado pela API (garante maiusculas corretas)
if not "!GH_LOGIN!"=="" set GH_USER=!GH_LOGIN!
if not "!GH_REPO!"=="" set REPO_NOME=!GH_REPO!

REM ════════════════════════════════════════════
REM  4. CONFIGURA GIT LOCAL
REM ════════════════════════════════════════════
echo.
if not exist ".git\" (
    echo [INFO] Inicializando repositorio Git...
    git init -b main >nul 2>&1
    if errorlevel 1 ( git init >nul 2>&1 & git checkout -b main >nul 2>&1 )
    echo [OK] Repositorio inicializado.
)

if not exist ".gitignore" (
    (
        echo .DS_Store
        echo Thumbs.db
        echo desktop.ini
        echo .vscode/
        echo .idea/
        echo *.log
        echo .env
    ) > .gitignore
)

for /f "delims=" %%e in ('git config user.email 2^>nul') do set GIT_EMAIL=%%e
if "!GIT_EMAIL!"=="" (
    git config user.name "!GH_USER!"
    git config user.email "!GH_USER!@users.noreply.github.com"
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin "https://!GH_USER!:!GH_TOKEN!@github.com/!GH_USER!/!REPO_NOME!.git"
) else (
    git remote set-url origin "https://!GH_USER!:!GH_TOKEN!@github.com/!GH_USER!/!REPO_NOME!.git"
)

echo [INFO] Adicionando arquivos...
git add .
git diff --cached --quiet >nul 2>&1
if errorlevel 1 (
    git commit -m "feat: publica Black Roads" >nul 2>&1
    echo [OK] Commit criado.
) else (
    echo [OK] Sem alteracoes novas.
)

REM ════════════════════════════════════════════
REM  5. PUSH
REM ════════════════════════════════════════════
echo.
echo [INFO] Enviando arquivos para o GitHub...
git push -u origin main
if errorlevel 1 (
    echo [INFO] Tentando com push forcado...
    git push -u origin main --force
    if errorlevel 1 (
        echo [ERRO] Nao foi possivel enviar. Verifique o token e tente de novo.
        goto :fim
    )
)
echo [OK] Arquivos enviados!

REM ════════════════════════════════════════════
REM  6. ATIVA GITHUB PAGES
REM ════════════════════════════════════════════
echo.
echo [INFO] Ativando GitHub Pages...

node "%~dp0publicar.js" "!GH_USER!" "!GH_TOKEN!" "!REPO_NOME!" "ativar-pages" > "%TEMP%\br_pages.txt" 2>&1
set /p PAGES_RESULT=<"%TEMP%\br_pages.txt"

if "!PAGES_RESULT!"=="OK" (
    echo [OK] GitHub Pages ativado!
) else (
    echo [AVISO] !PAGES_RESULT!
    echo         Va em Settings ^> Pages ^> Source e selecione "GitHub Actions".
)

REM ════════════════════════════════════════════
REM  7. RESULTADO FINAL
REM ════════════════════════════════════════════
echo.
echo  ============================================
echo   Tudo pronto!
echo  ============================================
echo.
echo  Repositorio : https://github.com/!GH_USER!/!REPO_NOME!
echo  Site        : https://!GH_USER!.github.io/!REPO_NOME!
echo.
echo  O site fica no ar em cerca de 2 minutos.
echo  Acompanhe: https://github.com/!GH_USER!/!REPO_NOME!/actions
echo.

start "" "https://github.com/!GH_USER!/!REPO_NOME!"

:fim
echo.
echo  Pressione qualquer tecla para fechar...
pause >nul
endlocal
