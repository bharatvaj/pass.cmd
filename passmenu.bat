@echo off
setlocal
:: Windows batch equivalent of passmenu

if not defined PASSWORD_STORE_DMENU (
    set "PASSWORD_STORE_DMENU=wlines.exe"
)

if not defined PASSWORD_STORE_DIR set "PASSWORD_STORE_DIR=%USERPROFILE%\.local\share\pass"
if not defined PASSTOOL set "PASSTOOL=pass"

if not exist "%PASSWORD_STORE_DIR%" (
    echo %PASSWORD_STORE_DIR% not set
    exit /b 1
)

for /f "usebackq" %%I in (`pass ls ^| %PASSWORD_STORE_DMENU%`) do (
    set selected_pass=%%I
)

if "%selected_pass%" equ "" (
    exit /b
)

if "%1" equ "" (
    if "%selected_pass:~0,5%" equ "totp\" (
        "%PASSTOOL%" otp "%selected_pass%"
    ) else (
        "%PASSTOOL%" show -c "%selected_pass%"
    )
) else (
    "%PASSTOOL%" %* "%selected_pass%"
)

endlocal
