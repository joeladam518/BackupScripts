@ECHO OFF
setlocal enableDelayedExpansion

REM Used for outputting a /n (newline) in the cmd screen...
REM -> Start newline
SET nl=^


REM -> END newline **Has to be 2 new lines after the set command or it doesn't work**

REM Set defualt Source and Destination paths..
SET "defSrcPth=m:\"
SET "defDesPth=n:\"

REM Set log file path..		****Make sure you replace "Your Username" with your username...****
SET "logPth=C:\Users\Your Username\Desktop\backup_log.txt"

:PROMPT
REM Ask the user to enter the Src and Des paths..
ECHO Please enter the Source and Destination paths or hit Enter to try the default paths...
ECHO Examples: "g:\" or "h:\folderpath" or "\\server\sambashare"
ECHO.

REM If the user dosen't enter anything for the Source Path then try the default Source Path.
SET /P "srcPthInpt=Please the Source Path or just hit Enter: "
IF DEFINED srcPthInpt (
	ECHO The Source Drive is defined. YAY
	ECHO Setting "!srcPthInpt!" to Source Path...
	SET "srcPth=!srcPthInpt!"
	ECHO Source Path is "!srcPth!"
	ECHO.
) ELSE (
	ECHO You did not enter anything for the Source...
	ECHO Setting the default Source Path of "!defSrcPth!" to the Source Path...
	SET "srcPth=!defSrcPth!"
	ECHO.
)

REM If the user dosen't enter anything for the Destination Path then try the default Destination Path.
SET /P "desPthInpt=Please enter Destination Path or just hit Enter: "
IF DEFINED desPthInpt (
	ECHO The Destination path is defined. YAY
	ECHO Setting "!desPthInpt!" to Destination Path..
	SET "desPth=!desPthInpt!"
	ECHO Destination path is "!desPth!"
	ECHO.
) ELSE (
	ECHO You did not enter anything for the Destination...
	ECHO Setting the default Destination Path of "!defDesPth!" to the Destination Path...
	SET "desPth=!defDesPth!"
	ECHO.
)

:EXISTSSS
REM Check if the Source and Destination paths Exist
IF EXIST !srcPth! (
	ECHO "!srcPth!" -- Source file path exists. We're good to go.
) ELSE (
	ECHO "!srcPth!" is not a valid Destination file path try again...
	GOTO END
)
IF EXIST !desPth! (
	ECHO "!desPth!" -- Destination file path exists. We're good to go.
) ELSE (
	ECHO "!desPth!" is not a valid Destination file path. try again...
	GOTO END
)
ECHO.
ECHO.

:ARESURE
SET /P "AREYOUSURE=Are you sure you want to copy !nl!!nl!'!srcPth!' to '!desPth!'!nl!!nl!(Y/[N])? "
IF /I "!AREYOUSURE!" NEQ "Y" GOTO END

robocopy !srcPth! !desPth! /ZB /J /MIR /COPY:DAT /DCOPY:DAT /XA:SH /XF Thumbs.db thumbs.db *.tmp /XD $RECYCLE.BIN RECYCLER "System Volume Information" .tmp cache /XJ /FFT /R:5 /W:5 /V /TS /FP /NP /ETA "/LOG:!logPth!" /TEE
attrib -h -s -a !desPth!

:END
Pause
endlocal
