@echo off
REM ============================================================
REM  JHF Website — Push to GitHub
REM  Asks for your GitHub username + Personal Access Token (PAT)
REM  every time it runs. Nothing is saved to disk or git config.
REM
REM  One-time prep (only if the repo doesn't exist yet):
REM    1. Create an empty repo on github.com (no README).
REM    2. Create a PAT: GitHub > Settings > Developer settings >
REM       Personal access tokens > Generate new token (classic),
REM       tick the "repo" scope.
REM ============================================================
setlocal
cd /d "%~dp0"

REM --- Make sure git is installed ---
where git >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Git is not installed. Download from https://git-scm.com
  pause
  exit /b 1
)

echo.
echo --- GitHub details ---------------------------------------
set /p GH_USER=GitHub username:
if "%GH_USER%"=="" (
  echo [ERROR] Username is required.
  pause
  exit /b 1
)

set "PS_COMMAND=Read-Host 'Personal access token (input hidden)'"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$s = Read-Host 'Personal access token (input hidden)' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))"`) do set "GH_TOKEN=%%i"
if "%GH_TOKEN%"=="" (
  echo [ERROR] Token is required.
  pause
  exit /b 1
)

set /p GH_REPO=Repository name (e.g. jhf-website):
if "%GH_REPO%"=="" set "GH_REPO=jhf-website"

REM Branch is fixed to main — no prompt needed.
set "BRANCH=main"

echo.
echo --- Committing changes ----------------------------------

REM --- First-time repo setup ---
if not exist ".git" (
  echo Initializing new repository...
  git init -b %BRANCH%
  git branch -M %BRANCH% >nul 2>nul
)

git add -A

REM --- Skip commit if nothing changed ---
git diff --cached --quiet
if errorlevel 1 (
  if "%COMMIT_MSG%"=="" (
    for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format \"yyyy-MM-dd HH:mm\""') do set "STAMP=%%d"
    git commit -m "Website update %STAMP%"
  ) else (
    git commit -m "%COMMIT_MSG%"
  )
) else (
  echo Nothing new to commit — pushing existing state.
)

echo.
echo --- Ensuring repository exists ---------------------------

REM Create the repo automatically if it doesn't exist yet.
powershell -NoProfile -Command ^
  "$body = @{ name = '%GH_REPO%'; private = $false; auto_init = $false } | ConvertTo-Json;" ^
  "$h = @{ Authorization = 'token %GH_TOKEN%'; 'User-Agent' = '%GH_USER%' };" ^
  "try { Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Method Post -Body $body -Headers $h | Out-Null; Write-Host 'Repository created.' }" ^
  "catch { $m = $_.ErrorDetails.Message; if ($m -match 'already exists') { Write-Host 'Repository already exists.' } else { Write-Host ('Could not create repo: ' + $_.Exception.Message) } }"

echo.
echo --- Pushing to GitHub -----------------------------------
git remote remove origin >nul 2>nul
git remote add origin https://github.com/%GH_USER%/%GH_REPO%.git

REM Token passed inline on the push URL only — never written to .git/config.
git push -u https://%GH_USER%:%GH_TOKEN%@github.com/%GH_USER%/%GH_REPO%.git %BRANCH%

if errorlevel 1 (
  echo.
  echo [ERROR] Push failed. Common causes:
  echo   - Wrong username or expired token
  echo   - Token missing the "repo" permission scope ^(needed to create repos too^)
  echo   - Fine-grained token without access to this repository
) else (
  echo.
  echo [SUCCESS] Pushed to https://github.com/%GH_USER%/%GH_REPO%
)

echo.
REM --- Clear the token from memory ---
set "GH_TOKEN="
endlocal
pause
