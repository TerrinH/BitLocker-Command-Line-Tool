@ECHO OFF
::Made by Terrin Hamilton 7/20/17
::Under GPL v3 License
TITLE BitLocker Tool v2.0
SETLOCAL ENABLEDELAYEDEXPANSION

::#########################################################################################
::############## Checking for and Requesting Administrative Privillages ###################
::#########################################################################################
:UAC
CLS
COLOR 0A

::Here I test for administrative privillages by reading the ERRORLEVEL result of the attempt.
IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
	"%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system" >NUL 2>&1
) ELSE (
	"%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system" >NUL 2>&1
)

IF "%ERRORLEVEL%" NEQ "0" (
    ECHO Requesting administrative privileges...
    GOTO UACPrompt
) ELSE (GOTO GotAdmin)

::Create a Visual Basic script to relaunch this program while requesting aforementioned privillages.
:UACPrompt
    ECHO SET UAC=CreateObject^("Shell.Application"^) > "%USERPROFILE%\GetUAC.vbs"
    SET Params = %*:"=""
    ECHO UAC.ShellExecute "cmd.exe", "/C ""%~s0"" %Params%", "", "runas", 1 >> "%USERPROFILE%\GetUAC.vbs"

    "%USERPROFILE%\GetUAC.vbs"
    DEL "%USERPROFILE%\GetUAC.vbs"
    EXIT /B

:GotAdmin
    PUSHD "%CD%"
    CD /D "%~dp0"
::#########################################################################################

::#########################################################################################
::############## Main Program Menu ##################################################
::#########################################################################################
:START
::Initialize global variables.
::Trim a specific number of characters off of a variable value using: ":~X,Y".
SET "Today=%DATE:~4%"
SET "DirName=%Today:/=-%"
SET SerialInfo=WMIC BIOS GET SERIALNUMBER /FORMAT:VALUE
FOR /F "TOKENS=2 DELIMS==" %%A IN ('%SerialInfo%') DO (SET Serial=%%A)
SET "Customer_Path=%CD:~0,3%Customers\"
::Created a spacer variable because the parenthesis was screwing with the compiler when within a code block, escaping didn't seem to help.
SET "Spacer=.) "
SET "LoopTempVar=0"

CLS
COLOR 0A
ECHO 1.) Enable BitLocker.
ECHO 2.) Disable BitLocker.
ECHO 3.) Show De/Encryption Progress.
ECHO 4.) Show BitLocker ID and Keys for Local Machine.
ECHO 5.) Exit
ECHO.
ECHO.
ECHO Select an operation: {1/2/3}
SET /P "Selection="
IF "%Selection%" EQU "1" (GOTO EnableBL)
IF "%Selection%" EQU "2" (GOTO DisableBL)
IF "%Selection%" EQU "3" (GOTO ShowProg)
IF "%Selection%" EQU "4" (GOTO ShowBL)
IF "%Selection%" EQU "5" (GOTO EOF)
::#########################################################################################

::#########################################################################################
::############## The Universal Invalid Input Error Message ################################
::#########################################################################################
:ERROR
COLOR 0C
CLS
ECHO Please select a valid option.
PAUSE
GOTO START
::#########################################################################################

::#########################################################################################
::############## BitLocker Save Error Message #############################################
::#########################################################################################
:SaveError
COLOR 0C
CLS
ECHO Unable to save BitLocker information!
ECHO.
ECHO You may have to use option 4 to display BitLocker information and record it manually.
PAUSE
GOTO START
::#########################################################################################

::#########################################################################################
::############## Dynamically Generate Encryption Options Menu #############################
::#########################################################################################
:EnableBL
CLS
ECHO Detected valid encryption methods for this machine:
FOR /F "TOKENS=1* DELIMS=:," %%A IN ('MANAGE-BDE -ON C: -EM /? ^| FINDSTR /B /I /C:"Valid encryption methods: "') DO (
	SET "RawEncryptMethods=%%B"
	SET "RefinedEncryptMethods=!RawEncryptMethods: =!"
	SET "EncryptMethods=!RefinedEncryptMethods:.=!"
)
SET "EncryptCount=0"
:EncryptLoop
FOR /F "TOKENS=1* DELIMS=," %%A IN ("%EncryptMethods%") DO (
	IF "%%A" NEQ "" (
		SET /A "EncryptCount+=1"
		SET "EncryptOption[!EncryptCount!]=%%A"
		SET "EncryptOptionName=%%A"
		SET "Output=!!EncryptCount!!Spacer!!EncryptOptionName!!"
		ECHO !Output!
	)
	IF "%%B" NEQ "" (
		SET "EncryptMethods=%%B"
		GOTO EncryptLoop
	)
)
ECHO.
ECHO NOTE: XTS encryption methods only work with Windows 10 and newer Windows OSs.
ECHO.
ECHO Please select an encryption method/strength: {1/2/3}
SET /P "EncryptSelection="
SET /A "DataValidation=%EncryptSelection%"
IF /I "%DataValidation%" EQU "0" (GOTO ERROR)
IF /I "%EncryptSelection%" GTR "%EncryptCount%" (GOTO ERROR)
IF /I "%EncryptSelection%" LSS "0" (GOTO ERROR)
::############### Fall-Through To: ########################################################

::#########################################################################################
::############## Dynamically Generate Customer Directory Menu #############################
::############## And Enable BitLocker if All Goes Well ####################################
:CustomerEnable
SET /A "CustomerCount=0"
CLS
::Gather all the customer names within the "Customers" directory and add their directories as options for saving BitLocker information to.
FOR /D %%B IN ("%Customer_Path%*.*") DO (
	SET /A "CustomerCount+=1"
	SET "DirPath=%%B"
	SET "CustomerName=!DirPath:~13!"
	::I'm honestly surprised that adding all these exclamation points worked...
	SET "Output=!!CustomerCount!!Spacer!!CustomerName!!"
	SET "Customer[!CustomerCount!]DirToday=!DirPath!\BitLocker\Script Captures\!DirName!"
	ECHO !Output!
)
SET /A "CustomerCount+=1"
ECHO !CustomerCount!.) Create new customer directory
ECHO.
ECHO Select a customer directory to save the BitLocker information to: {1/2/3}
SET /P "Selection="
SET /A "DataValidation=%Selection%"
::Here I make sure that the given input is in fact a number and that it is within the generated range of options.
IF /I "%DataValidation%" EQU "0" (GOTO ERROR)
IF /I "%Selection%" GTR "%CustomerCount%" (GOTO ERROR)
IF /I "%Selection%" LSS "0" (GOTO ERROR)
IF /I "%Selection%" EQU "%CustomerCount%" (GOTO NewCustomer)
::Created the temporary variable below as a fail-safe to be sure the loop doesn't attempt to become infinite.
SET "LoopTempVar=%EncryptSelection%+1"
CLS
FOR /L %%A IN (%EncryptSelection%, 1, %LoopTempVar%) DO (
	MANAGE-BDE -ON C: -RP -EM !EncryptOption[%%A]! -USED
	SET "LoopTempVar=%Selection%+1"
	FOR /L %%B IN (!Selection!, 1, !LoopTempVar!) DO (
		IF NOT EXIST "!Customer[%%B]DirToday!" MKDIR "!Customer[%%B]DirToday!"
		MANAGE-BDE -PROTECTORS -GET C: > "!Customer[%%B]DirToday!\%Serial%.txt"
		GOTO ExitEnableLoop
	)
)
:ExitEnableLoop
SHUTDOWN -R -T 2
EXIT /B
::#########################################################################################

::#########################################################################################
::############## Create A New Customer Directory To Save BitLocker Keys To ################
::#########################################################################################
:NewCustomer
CLS
ECHO Please enter the full name of the new customer directory to be created:
ECHO.
SET /P "NewCustomerName="
IF /I "%NewCustomerName%" EQU "" (GOTO ERROR)
IF NOT EXIST "%Customer_Path%%NewCustomerName%" MKDIR "%Customer_Path%%NewCustomerName%"
IF EXIST "%Customer_Path%%NewCustomerName%" (
	ECHO Confirmed %Customer_Path%%NewCustomerName%
	ECHO.
	PAUSE
	GOTO CustomerEnable
) ELSE (
	COLOR 0C
	ECHO Unable to create %Customer_Path%%NewCustomerName%
	ECHO.
	PAUSE
	GOTO START
)
::#########################################################################################

::#########################################################################################
::############## Disable BitLocker Encryption and Delete Saved Keys #######################
::#########################################################################################
:DisableBL
SET /A "CustomerCount=0"
CLS
::Gather all the customer names within the "Customers" directory and add their directories as options for removing BitLocker information from.
FOR /D %%A IN ("%Customer_Path%*.*") DO (
	SET /A "CustomerCount+=1"
	SET "DirPath=%%A"
	SET "CustomerName=!DirPath:~13!"
	::I'm honestly surprised that adding all these exclamation points worked...
	SET "Output=!!CustomerCount!!Spacer!!CustomerName!!"
	SET "Customer[!CustomerCount!]Dir=!DirPath!\BitLocker\Script Captures"
	ECHO !Output!
)
ECHO.
ECHO Select a customer directory to remove the BitLocker information from: {1/2/3}
SET /P "Selection="
SET /A "DataValidation=%Selection%"
::Here I make sure that the given input is in fact a number and that it is within the generated range of options.
IF /I "%DataValidation%" EQU "0" (GOTO ERROR)
IF /I "%Selection%" GTR "%CustomerCount%" (GOTO ERROR)
IF /I "%Selection%" LSS "0" (GOTO ERROR)
::Created the temporary variable below as a fail-safe to be sure the loop doesn't attempt to become infinite.
SET "LoopTempVar=%Selection%+1"
CLS
FOR /L %%A IN (%Selection%, 1, %LoopTempVar%) DO (
	MANAGE-BDE -OFF C:
	IF EXIST "!Customer[%%A]Dir!" (
		FOR /F %%B IN ('DIR "!Customer[%%A]Dir!" "%Serial%.txt" /S /B') DO (ECHO.)
		IF "%ERRORLEVEL%" EQU "0" (
			DEL "!Customer[%%A]Dir!\!DirName!\%Serial%.txt" 1>NUL
			ECHO Removed the recovery key file from the Flash Drive %CD:~0,3% as well.
		) ELSE (
			ECHO No such BitLocker information for %Serial% was found, no information was removed from Flash Drive %CD:~0,3%.
		)
	) ELSE (
		ECHO No such BitLocker directory exists for that customer, no stored information to remove from Flash Drive %CD:~0,3%.
	)
	GOTO ExitDisableLoop
)
:ExitDisableLoop
ECHO.
PAUSE
GOTO START
::#########################################################################################

::#########################################################################################
::############## Show BitLocker (De)Encryption Progress with a Loop #######################
::#########################################################################################
:ShowProg
CLS
FOR /F "TOKENS=1 DELIMS=" %%A IN ('MANAGE-BDE -STATUS ^| FINDSTR /I "Volume Conversion Percentage Encryption"') DO (ECHO %%A)
ECHO.
TIMEOUT /T 10 /NOBREAK
GOTO ShowProg
::#########################################################################################

::#########################################################################################
::############## Fetch and Display Current BitLocker Status of Local Machine ##############
::#########################################################################################
:ShowBL
CLS
MANAGE-BDE -PROTECTORS -GET C:
ECHO.
ECHO Would you like to save this information to the Flash Drive %CD:~0,3%? {Y/N}
SET /P "Input="
IF /I "%Input%" EQU "Y" GOTO SAVE
IF /I "%Input%" EQU "N" GOTO START
GOTO ERROR
::############## Fall-Through To: #########################################################

::#########################################################################################
::############## Fetch and Save BitLocker Keys of Local Machine ###########################
::#########################################################################################
:SAVE
SET /A "CustomerCount=0"
CLS
::Gather all the customer names within the "Customers" directory and add their directories as options for saving BitLocker information to.
FOR /D %%A IN ("%Customer_Path%*.*") DO (
	SET /A "CustomerCount+=1"
	SET "DirPath=%%A"
	SET "CustomerName=!DirPath:~13!"
	::I'm honestly surprised that adding all these exclamation points worked...
	SET "Output=!!CustomerCount!!Spacer!!CustomerName!!"
	SET "Customer[!CustomerCount!]DirToday=!DirPath!\BitLocker\Script Captures\!DirName!"
	ECHO !Output!
)
ECHO.
ECHO Select a customer directory to save the BitLocker information to: {1/2/3}
SET /P "Selection="
SET /A "DataValidation=%Selection%"
::Here I make sure that the given input is in fact a number and that it is within the generated range of options.
IF /I "%DataValidation%" EQU "0" (GOTO ERROR)
IF /I "%Selection%" GTR "%CustomerCount%" (GOTO ERROR)
IF /I "%Selection%" LSS "0" (GOTO ERROR)
::Created the temporary variable below as a fail-safe to be sure the loop doesn't attempt to become infinite.
SET "LoopTempVar=%Selection%+1"
CLS
FOR /L %%A IN (%Selection%, 1, %LoopTempVar%) DO (
	IF NOT EXIST "!Customer[%%A]DirToday!" MKDIR "!Customer[%%A]DirToday!"
	MANAGE-BDE -PROTECTORS -GET C: > "!Customer[%%A]DirToday!\%Serial%.txt"
	IF EXIST "!Customer[%%A]DirToday!\%Serial%.txt" (
		ECHO Confirmed "!Customer[%%A]DirToday!\%Serial%.txt".
	) ELSE (
		COLOR 0C
		ECHO Unable to save "!Customer[%%A]DirToday!\%Serial%.txt".
	)
	GOTO ExitSaveLoop
)
:ExitSaveLoop
PAUSE
GOTO START
::#########################################################################################

:EOF
ENDLOCAL
EXIT /B