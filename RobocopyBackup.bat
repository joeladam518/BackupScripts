@ECHO OFF
setlocal enableDelayedExpansion

REM # Used for outputting a /n (newline) in the cmd screen...
REM # Start newline
SET nl=^


REM # END newline 
REM # It has to be 2 new lines after the set command or it doesn't work.

REM # Set defualt Source and Destination paths...
SET "defSrcPth=m:\"
SET "defDesPth=n:\"

REM # Set log file path... 
REM # Make sure you replace "user name" with your user name.

:PROMPT
REM # Ask the user to enter the Src and Des paths..
ECHO Please enter the Source and Destination paths or hit enter to try the default paths...
ECHO Examples: "g:\" or "h:\folderpath" or "\\server\sambashare"
ECHO.

REM # If the user doesn't enter anything for the source path then try the default source path.
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

REM # If the user doesn't enter anything for the destination path then try the default destination path.
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
REM # Check if the source and destination paths exist.
IF EXIST !srcPth! (
	ECHO "!srcPth!" -- Source file path exists. We're good to go.
) ELSE (
	ECHO "!srcPth!" is not a valid file path. Try Again...
	GOTO END
)
IF EXIST !desPth! (
	ECHO "!desPth!" -- Destination file path exists. We're good to go.
) ELSE (
	ECHO "!desPth!" is not a valid file path. Try Again...
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
