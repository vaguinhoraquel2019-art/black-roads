@echo off
setlocal EnableDelayedExpansion

REM ── Reabrir em terminal persistente ao dar duplo clique ──────────────────────
if /i "%1" NEQ "--ja-aberto" (
    cmd /k ""%~f0" --ja-aberto"
    exit /b
)

echo.
echo  ============================================
echo   Black Roads - Sincronizar com GitHub
echo  ============================================
echo.

REM ════════════════════════════════════════════
REM  VERIFICA GIT
REM ════════════════════════════════════════════
where git >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Git nao encontrado.
    echo  Instale em: https://git-scm.com/download/win
    goto :fim
)

REM ════════════════════════════════════════════
REM  VERIFICA SE TEM REPOSITORIO CONFIGURADO
REM ════════════════════════════════════════════
if not exist ".git\" (
    echo [ERRO] Repositorio Git nao encontrado nesta pasta.
    echo  Execute o publicar.bat primeiro para configurar.
    goto :fim
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Nenhum repositorio remoto configurado.
    echo  Execute o publicar.bat primeiro.
    goto :fim
)

for /f "tokens=*" %%u in ('git remote get-url origin') do set REPO_URL=%%u
echo [OK] Repositorio: !REPO_URL!
echo.
echo  Monitorando alteracoes... (pressione Ctrl+C para parar)
echo  Qualquer arquivo salvo sera enviado automaticamente.
echo.
echo ─────────────────────────────────────────────

REM ════════════════════════════════════════════
REM  LOOP DE MONITORAMENTO
REM ════════════════════════════════════════════
set ULTIMO_ESTADO=
set CONTADOR=0

:loop
REM Captura o estado atual dos arquivos (hash do git status)
for /f "tokens=*" %%h in ('git status --porcelain 2^>nul') do (
    set ESTADO_ATUAL=%%h
    goto :verificar
)
set ESTADO_ATUAL=

:verificar
REM Compara com o estado anterior
if "!ESTADO_ATUAL!"=="" (
    REM Nenhuma alteracao pendente
    set /a CONTADOR=CONTADOR+1
    REM Mostra ponto a cada 12 ciclos (~1 minuto) para mostrar que esta ativo
    set /a RESTO=CONTADOR %% 12
    if "!RESTO!"=="0" (
        set /a MINUTOS=CONTADOR/12
        echo   [!time:~0,5!] Aguardando alteracoes... (!MINUTOS! min)
    )
) else (
    REM Ha alteracoes — envia para o GitHub
    echo.
    echo  [!time:~0,5!] Alteracoes detectadas! Enviando...
    echo.

    git add .

    REM Gera mensagem de commit com data e hora
    set DT=%date:~6,4%-%date:~3,2%-%date:~0,2%
    set HR=%time:~0,2%:%time:~3,2%
    set HR=!HR: =0!
    git commit -m "update: !DT! !HR!" >nul 2>&1

    git push origin main
    if errorlevel 1 (
        echo  [ERRO] Falha ao enviar. Tentando de novo em 10s...
    ) else (
        echo  [OK] Enviado com sucesso!
        echo       Site atualizado em ~1 minuto no GitHub Pages.
    )
    echo.
    echo ─────────────────────────────────────────────
    set CONTADOR=0
)

REM Aguarda 5 segundos antes de verificar de novo
timeout /t 5 /nobreak >nul
goto :loop

:fim
echo.
echo  Pressione qualquer tecla para fechar...
pause >nul
endlocal
