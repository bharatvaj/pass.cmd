@echo off
set PASS_VERSION=0.2
set PROGRAM=pass
if not defined PASSWORD_STORE_DIR set "PASSWORD_STORE_DIR=%USERPROFILE\.password-store"
if not defined GPG set "GPG=gpg.exe"
:: TODO Add PASSWORD_STORE_GPG_OPTS to GPG_OPTS without %PASSWORD_STORE_GPG_OPTS% artifact
if not defined GPG_OPTS set "GPG_OPTS=--quiet --yes --compress-algo=none --no-encrypt-to"

goto :main

:print_version
echo pass.cmd v%PASS_VERSION% - the standard unix password manager
echo                 now on windows^^!
goto :eof

:print_usage
call :print_version
echo Usage:
echo    pass show [-c]
echo        Show existing password and optionally put it on the clipboard.
echo        If put on the clipboard, it will be cleared in 45 seconds.
echo    pass [ls] [subfolder]
echo        List passwords.
echo    pass edit pass-name
echo        Insert a new password or edit an existing password using vi.
echo    pass otp [-c]
echo    pass git git-command-args...
echo        If the password store is a git repository, execute a git command
echo        specified by git-command-args.
echo    pass help
echo        Show this text.
echo    pass version
echo        Show version information.
goto :eof

:pass_show
setlocal
    if not exist "%PASSWORD_STORE_DIR%\%~1.gpg" (
        echo Error: '%~1' does not exist >&2
        exit /b 1
    )
    gpg -d %GPG_OPTS% "%PASSWORD_STORE_DIR%\%~1.gpg"
endlocal
goto :eof

:pass_insert
setlocal
    echo %*
endlocal
goto :eof

:pass_check_sneaky_paths
setlocal EnableDelayedExpansion
    set "path=%*"
    if not "!path:..=!" == "!path!" (
		echo Error: You've attempted to pass a sneaky path to pass. Go home.
        exit /b 1
    )
endlocal DisableDelayedExpansion
goto :eof

:pass_set_git
setlocal EnableDelayedExpansion
    rem Start from the directory portion of the provided path.
    set "INNER_GIT_DIR=%~dp1"
    if "!INNER_GIT_DIR:~-1!"=="\" set "INNER_GIT_DIR=!INNER_GIT_DIR:~0,-1!"

    rem Use PASSWORD_STORE_DIR as the prefix boundary (similar to PREFIX in the sh version).
    set "PREFIX_DIR=%PASSWORD_STORE_DIR%"
    if "!PREFIX_DIR:~-1!"=="\" set "PREFIX_DIR=!PREFIX_DIR:~0,-1!"
    set "PREFIX_BOUND=!PREFIX_DIR!\"

    rem Walk up until we find an existing directory or leave the prefix boundary.
    :pass_set_git_walk
        if exist "!INNER_GIT_DIR!\*" goto :pass_set_git_check
        for %%p in ("!INNER_GIT_DIR!") do set "PARENT_DIR=%%~dpp"
        if "!PARENT_DIR:~-1!"=="\" set "PARENT_DIR=!PARENT_DIR:~0,-1!"
        echo(!PARENT_DIR!|findstr /i /b /c:"!PREFIX_BOUND!" >nul
        if errorlevel 1 (
            set "INNER_GIT_DIR="
            goto :pass_set_git_done
        )
        set "INNER_GIT_DIR=!PARENT_DIR!"
        goto :pass_set_git_walk

    rem Verify the located directory is inside a git work tree.
    :pass_set_git_check
        set "git_inside="
        for /f %%g in ('git -C "!INNER_GIT_DIR!" rev-parse --is-inside-work-tree 2^>nul') do set "git_inside=%%g"
        if /i not "!git_inside!"=="true" set "INNER_GIT_DIR="

    :pass_set_git_done
set "result=!INNER_GIT_DIR!"
endlocal & set "INNER_GIT_DIR=%result%"
goto :eof

:__git_add_file
setlocal EnableDelayedExpansion
    if "!INNER_GIT_DIR!" == "" exit /b 0
    git -C "!INNER_GIT_DIR!" add "%~1"
    if ERRORLEVEL 1 exit /b 0
    git -C "!INNER_GIT_DIR!" status --porcelain "%~1"
    call :__git_commit "%~2"
endlocal DisableDelayedExpansion
goto :eof

:__git_commit
setlocal EnableDelayedExpansion
    set "sign="
    if "!INNER_GIT_DIR!" == "" exit /b 0
    git -C "!INNER_GIT_DIR!" config --bool --get pass.signcommits 2>nul | findstr true
    if ERRORLEVEL 0 set "sign=-S"
    git -C "!INNER_GIT_DIR!" commit !sign! -m "%~1"
endlocal DisableDelayedExpansion
goto :eof

:pass_init
setlocal
    for /f "tokens=1,2,3*" %%a in ("%*") do (
        if "%%a" == "-p" (
            set "id_path=%%b"
            echo !id_path!
            set "keys=%%c"
            set "id_path_print= ^(!id_path!^)"
        ) else (
            set "keys=%%a %%b %%c"
            set "id_path_print="
        )
        echo Keys: !keys!
    )
    if "!id_path!" == "" (
        set "id_path=."
        set "id_path_full=%PASSWORD_STORE_DIR%"
    ) else set "id_path_full=%PASSWORD_STORE_DIR%\!id_path!"
    rem TODO Print usage for pass_init
    call :pass_check_sneaky_paths !id_path!
    if ERRORLEVEL 1 (
        exit /b 1
    )
    echo ID Path Full: "!id_path_full!"
    if not exist "!id_path_full!\*" if exist "!id_path_full!" (
        echo Error: '!id_path_full!\*' exists but is not a directory.
        exit /b 1
    )
	set "gpg_id=!id_path_full!\.gpg-id"
    echo GPG ID: '!gpg_id!'
	call :pass_set_git !gpg_id!
    echo INNER_DIR: !INNER_GIT_DIR!
    if "%*" == "" (
        if not exist "!gpg_id!" (
            echo Error: '!gpg_id!' does not exist and so cannot be removed.
            exit /b 1
        )
        del /f !gpg_id!
        if ERRORLEVEL 1 (
            exit /b 1
        )
        echo INN: "!INNER_GIT_DIR!"
        if not "!INNER_GIT_DIR!" == "" (
            echo heelo
			git -C "!INNER_GIT_DIR!" rm -qr "!gpg_id!"
			echo git_commit "Deinitialize !gpg_id!!id_path_print!."
        )
        rem TODO Delete parents if empty
        echo GPG_ID !gpg_id!

		rmdir "!gpg_id!" 2>nul
    ) else (
        if not exist "!id_path_full!\*" (
            mkdir "!id_path_full!"
        )
		echo !keys! > "!gpg_id!"
        set "id_print="
        for %%a in (!keys!) do (
            set "id_print=%%a, "
        )
        set "id_print=!id_print:~0,-2!"
		echo Password store initialized for !id_print!!id_path_print!
		call :__git_add_file "!gpg_id!" "Set GPG id to !id_print!!id_path_print!."
        if not "%PASSWORD_STORE_SIGNING_KEY%" == "" (
            set "signing_keys="
			for %%k in (%PASSWORD_STORE_SIGNING_KEY%) do (
                set "signing_keys=!key! --default-key %%k"
            )
			%GPG% %GPG_OPTS% %signing_keys% --detach-sign "!gpg_id!"
            if not ERRORLEVEL 0 (
                echo Could not sign .gpg_id."
                exit /b 0
            )
			for %%c in (%GPG% %GPG_OPTS% --verify --status-fd=1 "!gpg_id!.sig" "!gpg_id!" 2^>nul ^| findstr /B /L /C:'[GNUPG:] VALIDSIG ') do (
                if "%%c" == "" (
                    echo Signing of .gpg_id unsuccessful.
                    exit /b 0
                )
                for %%g in (%%c) do set "last_arg=%%g"
                set "keys=!keys!,!last_arg!"
            )
            if not "!keys!" == "" (
                set "keys=!keys:~0,-1!"
                call :__git_add_file "!gpg_id!.sig" "Signing new GPG id with !keys!."
            )
        )
    )
	call :reencrypt_path "$PREFIX/$id_path"
	call :__git_add_file "!id_path_full!" "Reencrypt password store using new GPG id !id_print!!id_path_print!."
endlocal
goto :eof

:set_gpg_recipients
setlocal EnableDelayedExpansion
    set "GPG_RECIPIENT_ARGS="
    set "GPG_RECIPIENTS="

    if defined PASSWORD_STORE_KEY (
        for %%p in (!PASSWORD_STORE_KEY!) do (
            set "GPG_RECIPIENT_ARGS=!GPG_RECIPIENT_ARGS! -r %%p"
            set "GPG_RECIPIENTS=!GPG_RECIPIENTS! %%p"
        )
        set "GPG_RECIPIENTS=!GPG_RECIPIENTS:0,-1!"
        set "GPG_RECIPIENT_ARGS=!GPG_RECIPIENT_ARGS:0,-1!"
        exit /b 0
    )

    set "current=%PASSWORD_STORE_DIR%\%~1"

    echo current:            !current!
    echo PASSWORD_STORE_DIR: %PASSWORD_STORE_DIR%

    :check_for_gpg
    if not "!current!" == "%PASSWORD_STORE_DIR%" if not exist "!current!\.gpg-id" (
        for %%I in ("!current!") do set "current=%%~dpI"
        set "current=!current:~0,-1!"
        goto :check_for_gpg
    )
    set "current=!current!\.gpg-id"

    if not exist "!current!" (
		echo Error: You must run:
		echo    %PROGRAM% init your-gpg-id
		echo before you may use the password store.
        call :print_usage
        exit /b 1
    )

    call :verify_file "!current!"
    if ERRORLEVEL 1 exit /b 1

    for /f "usebackq" %%l in ("!current!") do (
        set "gpg_id=%%l"
        if "!gpg_id:#=!" == "!gpg_id!"  (
            rem TODO Sanitize input properly
            set "GPG_RECIPIENT_ARGS=!GPG_RECIPIENT_ARGS! -r !gpg_id!"
            set "GPG_RECIPIENTS=!GPG_RECIPIENTS! !gpg_id!"
        )
    )
    set "GPG_RECIPIENTS=!GPG_RECIPIENTS:0,-1!"
    set "GPG_RECIPIENT_ARGS=!GPG_RECIPIENT_ARGS:0,-1!"
endlocal DisableDelayedExpansion
goto :eof

:verify_file
setlocal EnableDelayedExpansion
    if not defined PASSWORD_STORE_SIGNING_KEY exit /b 0
    if not exist "%~1.sig" (
        echo Signature for '%~1' does not exist.
        exit /b 1
    )
    for /f "usebackq tokens=3,*" %%F in (`2^>nul %GPG% %GPG_OPTS% --verify --status-fd=1 "%~1.sig" "%~1" ^| findstr /B /L /C:"[GNUPG:] VALIDSIG"`) do (
        set "third_tok=%%F"
        set "last_tok=%%G"
        set "last_tok=!last_tok: =,!"
        for %%l in (%%G) do set "last_tok=%%l"
        set "fingerprints=!third_tok!,!last_tok!,"
    )

    for %%F in (%PASSWORD_STORE_SIGNING_KEY%) do (
        set "fingerprint=%%F"

        rem $fingerprint =~ ^[A-F0-9]{40}$
        rem findstr checks for [A-F0-9]* pattern in the string and 39,-1 substring
        rem returns the characters from 39 to last one, which is empty for 40 char string
        rem TODO Handle hashes with less than 40 chars
        echo.!fingerprint!| findstr /B /E [A-F0-9]*  >nul 2>nul
        if "!ERRORLEVEL!!fingerprint:~39,-1!" == "0" (
            rem check if %%F (which is fingerprint) is in fingerprints
            if not "!fingerprints:%%F=!" == "!fingerprints!" (
                exit /b 0
            )
        )
    )
    echo Signature for '%~1' is invalid.
    exit /b 1
endlocal DisableDelayedExpansion
goto :eof

:reencrypt_path
setlocal EnableDelayedExpansion
    if "%~1" == "" (
        set "passdir=%PASSWORD_STORE_DIR%\"
    ) else (
        set "passdir=%~1\"
    )
    for /f "usebackq tokens=*" %%c in (`%GPG% !PASSWORD_STORE_GPG_OPTS! --list-config --with-colons ^| findstr "cfg:group:.*"`) do set "groups=%%c"
    echo Groups: !groups!
    for /f "usebackq tokens=*" %%P in (`dir /b /r /s "!passdir!*.gpg"`) do (
        rem TODO/FIXME for may fail if %%P has spaces in it
        for %%a in (%%P) do set "attribs=%%~aa"
        rem TODO Test this check later
        if "!attribs:~8,1!" == "l" goto :next_dir
        set "passfile_dir=%%~dpP"
        set "passfile_dir=!passfile_dir:%PASSWORD_STORE_DIR%\=!"
        set "passfile_dir=!passfile_dir:~0,-1!"

        set "passfile_display=%%~dpnP"
        set "passfile_display=!passfile_display:%PASSWORD_STORE_DIR%\=!"
        set "passfile_temp=%%P.tmp.%RANDOM%.%RANDOM%.%RANDOM%.%RANDOM%.--"

        call :set_gpg_recipients "!passfile_dir!"

        echo starting if not "!prev_gpg_recipients!" == "!GPG_RECIPIENTS!"
        if not "!prev_gpg_recipients!" == "!GPG_RECIPIENTS!" (
            for %%i in (!GPG_RECIPIENTS!) do (
                rem TODO
				rem local group="$(sed -n "s/^cfg:group:$(sed 's/[\/&]/\\&/g' <<<"${GPG_RECIPIENTS[$index]}"):\\(.*\\)\$/\\1/p" <<<"$groups" | head -n 1)"
                set "group="
                if not "!group!" == "" (
                    rem TODO intepret the following code and implement
                    rem IFS=";" eval 'GPG_RECIPIENTS+=( $group )' # http://unix.stackexchange.com/a/92190
                    rem unset "GPG_RECIPIENTS[$index]"
                    echo placeholder
                )
            )
            rem TODO What does LC_ALL=C do and how to pass it?
            rem sort /L "C" does not have same collation as LC_ALL=C
            for /f "usebackq delims=: tokens=5" %%c in (`%GPG% %PASSWORD_STORE_GPG_OPTS% --list-keys --with-colons "!GPG_RECIPIENTS!" "%%P" ^| findstr /B "sub:[^idr:]*:[^:]*[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[a-zA-Z]*e[a-zA-Z]*:" ^| sort /unique /L "C"`) do (
                echo first %%c
                set "gpg_keys=%%c,"
            )
        )
        if "!gpg_keys:-1,1!" == "," set "gpg_keys=!gpg_keys:0,-1!"
        rem TODO What does LC_ALL=C do and how to pass it?
        for /f "usebackq tokens=5" %%c in (`2^>^&1 %GPG% %PASSWORD_STORE_GPG_OPTS% -v --no-secmem-warning --no-permission-warning --decrypt --list-only --keyid-format long "%%P" ^| findstr /B /L /C:"gpg: public key is " ^| sort /unique /L "C"`) do (
            set "current_keys=%%c,"
            echo Second !current_keys!
        )
        if "!current_keys:-1,1!" == "," set "current_keys=!current_keys:0,-1!"
        echo before "!gpg_keys!" == "!current_keys!"
        if not "!gpg_keys!" == "!current_keys!" (
            echo after "!gpg_keys!"
			echo !passfile_display!: reencrypting to !gpg_keys:,= !
			%GPG% -d %GPG_OPTS% "%%P" | %GPG% -e !GPG_RECIPIENT_ARGS! -o "!passfile_temp!" %GPG_OPTS%
            if ERRORLEVEL 0 (
                move "!passfile_temp!" "%%P"
                if exist "!passfile_temp!" del /f "!passfile_temp!"
            )
        )

        echo then
        set "prev_gpg_recipients=!GPG_RECIPIENT_ARGS!"

        set "file=%%P"
        :next_dir
        echo here in next_dir start/end
    )
endlocal DisableDelayedExpansion
goto :eof

:pass_edit
setlocal EnableDelayedExpansion
    if not defined VISUAL set VISUAL=notepad.exe
    set "pass_path=%PASSWORD_STORE_DIR%\%~1.gpg"

	if not exist "!pass_path!" (
        goto :pass_insert
    )

	gpg -d %GPG_OPTS% "!pass_path!"
    %VISUAL% 
endlocal DisableDelayedExpansion
goto :eof

:pass_otp
setlocal EnableDelayedExpansion
	if not exist "%PASSWORD_STORE_DIR%\%~1.gpg" (
		echo Error: '%~1' does not exist >&2
		exit /b 1
	)

	for /f "tokens=1,2 delims==&" %%k in ('gpg -d %GPG_OPTS% "%PASSWORD_STORE_DIR%\%~1.gpg"') do (
        for /f "tokens=1 delims=:" %%z in ("%%k") do (
            if not "%%z" == "otpauth" (
                echo Error: OTP URI invalid or not found for '%~1' >&2
                exit /b 1
            )
        )

        for /f "tokens=*" %%z in ('oathtool -b --totp %%l') do (
            if "%opt_clip%" == "1" (
                set /p"=%%z"<nul|clip
                call :pass_clip_expire
            ) else (
                set /p"=%%z"<nul
            )
        )
	)
endlocal DisableDelayedExpansion
goto :eof

:pass_clip_expire
setlocal
	start /b "" cmd /c "ping -n %PASSWORD_STORE_CLIP_TIME% 127.0.0.1 >nul & @echo off | clip"
	echo Password copied, expires in %PASSWORD_STORE_CLIP_TIME% seconds
endlocal
goto :eof

:pass_ls
setlocal EnableDelayedExpansion
for /f "tokens=2 delims=: usebackq" %%I in (`xcopy /L /S /Y /R /I "*.gpg" "%TEMP%"`) do (
	set "tok=%%I"
	echo !tok:~0,-4!
)
endlocal DisableDelayedExpansion
goto :eof

:main
setlocal EnableDelayedExpansion

if not defined PASSWORD_STORE_DIR set "PASSWORD_STORE_DIR=%USERPROFILE%\.password-store"
if not defined PASSWORD_STORE_CLIP_TIME set "PASSWORD_STORE_CLIP_TIME=45"
if not defined GPG_OPTS set "GPG_OPTS=-q --yes --compress-algo=none --no-encrypt-to --batch"

if not exist "%PASSWORD_STORE_DIR%" (
	echo Error: password store is empty. Try pass init. >&2
	exit /b 1
)

cd "%PASSWORD_STORE_DIR%"

set "arg=%~1"
shift
if "%arg%" == "" (
    tree /f /a | findstr /ri /c:"^[^| ]" /c:"^[| ]*[+\\]" /c:"\.gpg$" | more +3
) else if "%arg%" == "help" (
        call :print_usage
) else if "%arg%" == "se" (
    call :set_gpg_recipients "web\econnect.bpcl.in"
) else if "%arg%" == "ve" (
    call :verify_file "%PASSWORD_STORE_DIR%\web\.gpg-id"
) else if "%arg%" == "re" (
    call :reencrypt_path
) else if "%arg%" == "init" (
    set "init_args=%*"
    call :pass_init !init_args:~5!
) else if "%arg%" == "ls" (
	call :pass_ls
) else if "%arg%" == "show" (
	if "%~1" == "" (
		call :panic "Nothing?"
	) else if "%~1" == "-c" (
		set "opt_clip=1"
		call :pass_show "%~2"
	) else (
		call :pass_show "%~1"
	)
) else if "%arg%" == "edit" (
    call :pass_edit "%~1"
) else if "%arg%" == "otp" (
	if "%~1" == "" (
		call :panic "Nothing?"
	) else if "%~1" == "-c" (
		set "opt_clip=1"
		call :pass_otp "%~2"
	) else (
		call :pass_otp "%~1"
	)
) else if "%arg%" == "git" (
    set "git_args=%*"
    git -C "%PASSWORD_STORE_DIR%" !git_args:~4!
) else if "%arg%" == "version" (
    call :print_version
) else (
	call :pass_show "%arg%"
)

endlocal DisableDelayedExpansion
goto :eof
