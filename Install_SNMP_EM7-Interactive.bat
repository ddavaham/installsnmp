@echo off
REM Install_SNMP_EM7-Interactive.bat -> paste to server and run as administrator to install and/or fully configure SNMP
REM
REM If the SNMP service is not present this script can attempt to install the SNMP features for Windows server
REM versions 2008/2008R2/2012/2012R2/2016.
REM
REM Once SNMP is installed this script can be used to fully CONFIGURE the SNMP settings needed for EM7
REM to monitor a Windows server from either Allentown or Denver. It verifies the presence and state of
REM the SNMP service, if present but not Running then it will set it to start type of Automatic and attempt to start it.
REM 
REM Once SNMP service is confirmed to be running it prompts for which of the West Stack EM7 sites will 
REM monitor the server. Next it attempts to dynamically identify the CID from the hostname and requests
REM confirmation from user for whether to accept the parsed CID as the community string or allows the user 
REM to enter a different value for community string. It then presents a summary of what will be configured
REM for communitry string, list of poller IP's, and message collector IP for trap destination and prompts for 
REM final confirmation from the user before proceeding.
REM
REM This script respects and leaves alone any existing SNMP settings. It will configure a new community string
REM if it doesn't already exist. If there were existing community strings and no restrictions on permitted
REM managers the script recognizes that indicates the server was set to "Accept SNMP packets from any host"
REM and in that case it will not add the EM7 IP's since existence of any permitted managers removes the
REM acceptance from any host which could break existing monitoring.

cls
title EM7 SNMP Configuration Script
color 0a
setlocal enabledelayedexpansion
call :Init

REM Get windows Version numbers
For /f "tokens=2 delims=[]" %%G in ('ver') Do (set _version=%%G) 
For /f "tokens=2,3,4 delims=. " %%G in ('echo %_version%') Do (set _major=%%G& set _minor=%%H& set _build=%%I) 
REM Echo Major version: %_major%  Minor Version: %_minor%.%_build%

REM 2008 = 6.0
REM 2008 R2 = 6.1
REM Both can use servermanagercmd.exe to install the SNMP feature
set Is2008=0
if "%_major%"=="6" if "%_minor%"=="0" set Is2008=1
if "%_major%"=="6" if "%_minor%"=="1" set Is2008=1

REM 2012 = 6.2
REM 2012 R2 = 6.3
REM Both can use powershell "Add-WindowsFeature" to install the SNMP features
set Is2012=0
if "%_major%"=="6" if "%_minor%"=="2" set Is2012=1
if "%_major%"=="6" if "%_minor%"=="3" set Is2012=1

REM 2016 = 10.0
REM Can use powershell "Install-WindowsFeature SNMP-Service -IncludeManagementTools" to install the SNMP features
set Is2016=0
if "%_major%"=="10" if "%_minor%"=="0" set Is2016=1

REM Check if SNMP service is installed
sc query snmp > NUL
if not %errorlevel% equ 0 (
  echo.
  echo SNMP Service is not installed. Do you want to attempt to install SNMP?
  echo.
  set Confirm=n
  set /p Confirm=Continue [y/N]? 
  if /i not "!Confirm!"=="y" goto :eof
  echo.
  echo Checking if Windows 2008/2012/2016 and then using relevant command-line tool to try to add the SNMP feature.
  echo.
  if !Is2008! equ 1 (
    REM This is Windows 2008 or 2008 R2 and SNMP is not installed. Need to add the feature
    echo Windows 2008 Confirmed. Attempting SNMP feature add...
    echo.
    servermanagercmd -install SNMP-Services -allSubFeatures > NUL 
    if !errorlevel! equ 0 (
      REM Install successful
      echo SNMP Feature Add SUCCESS
      echo.
    ) else (
        if !errorlevel! equ 3010 (
          REM Install successful
          echo SNMP Feature Add SUCCESS
          echo.
        ) else (
            echo.
            echo SNMP Feature Add FAILURE. Aborting...
            echo.
            goto :eof
        )
    )
  ) else (
      REM Not 2008, let's see if 2012 or 2012 R2
      if !Is2012! equ 1 (
        REM This is Windows 2012 or 2012 R2 and SNMP is not installed. Need to add the feature
        echo Windows 2012 Confirmed. Attempting SNMP feature add...
        echo.
        REM powershell.exe -command "Add-WindowsFeature SNMP-Service"
        REM powershell.exe -command "Add-WindowsFeature SNMP-WMI-Provider"
        powershell.exe -command "Install-WindowsFeature SNMP-Service -IncludeAllSubFeature -IncludeManagementTools"

        if !errorlevel! equ 0 (
          ::Install successful
          echo SNMP Feature Add SUCCESS
		  echo.
        ) else (
            echo.
            echo SNMP Feature Add FAILURE. Aborting...
            echo.
            goto :eof
        )
      ) else (
        REM Not 2008 or 2012...is it 2016?
        if !Is2016! equ 1 (
          REM This is Windows 2016 and SNMP is not installed. Need to add the feature
          echo Windows 2016 Confirmed. Attempting SNMP feature add...
          echo.
          REM powershell.exe -command "Install-WindowsFeature SNMP-Service -IncludeManagementTools"
          powershell.exe -command "Install-WindowsFeature SNMP-Service -IncludeAllSubFeature -IncludeManagementTools"

          if !errorlevel! equ 0 (
            REM Install successful
            echo SNMP feature add SUCCESS
            echo.
          ) else (
              echo.
              echo SNMP feature add FAILURE. Aborting...
              echo.
              goto :eof
          )     
      
        ) else (
            echo.
            echo This is not a supported OS for this install script. Aborting...
            echo.
            goto :eof
        )
      )
  )	  
) else (
  echo.
  echo SNMP Service is already installed.
)


REM Check if SNMP service is running
sc query snmp | find "STATE" | find "RUNNING" > NUL
if not %errorlevel%	equ 0 (
  echo.
  echo SNMP Service not running. Attempting to set as Automatic startup type and Start the service.
  sc config snmp start= auto
  net start snmp
  if not !errorlevel! equ 1 (
    echo.
    echo SNMP Service failed to start.
	echo.
	echo Please investigate and run this script again once SNMP Service is running.
	pause
	goto :eof
  )
) else (
  echo.
  echo SNMP Service is running. Proceeding with SNMP configuration.
)


REM Ask user to specify ABE or DEN collector group
echo.
echo From which location will this device be monitored?
echo.
echo 	1.Allentown
echo 	2.Denver
echo.

choice /C 12 /M "Enter your choice: "
set selection=%errorlevel%
if %selection% equ 2 (
  echo.
  echo Using Denver EM7 Collector IP's
  echo.
  set AcceptedHosts=localhost 74.63.159.92 74.63.159.93 74.63.159.94 74.63.159.95 74.63.159.104 74.63.159.105
  set TrapDestinations=74.63.159.96
)
if %selection% equ 1 (
  echo.
  echo Using Allentown EM7 Collector IP's
  echo.
  set AcceptedHosts=localhost 209.235.239.73 209.235.239.74 209.235.239.75 209.235.239.76 209.235.239.82 209.235.239.83 192.168.227.122
  set TrapDestinations=209.235.239.77
)

REM Take characters before first dash as most likely MASSID / CID to use as community string
for /f "tokens=1 delims=-" %%a in ("%host%") do (
  set CID=%%a
)

REM For Puppet managed servers the community string is being set to Puppet environment which
REM is the MASSID <or> the numeric LVW CID with "_CID" text appended (ex. 12345_CID)
REM Check to see if the parsed out CID is numeric and append "_CID" when suggesting the
REM possible community string to use.
SET "var="&for /f "delims=0123456789" %%i in ("%CID%") do set "var=%%i"
if NOT defined var (set CID=%CID%_CID)


echo Community string to use based on parsed hostname: %CID%
echo.
set Confirm=n
set /p Confirm=Do you want to use %CID% as SNMP community string? [y/N]
if /i "%Confirm%"=="y" (
  set Community=%CID%
) else (
  REM Parsed CID not accepted, need to prompt for user input
  echo.
  set CommunityPrompt=BLANK
  set /p CommunityPrompt=Enter the desired community string:
  if "!%CommunityPrompt!"=="BLANK" (
    echo.
    echo No community string was entered. Exiting...
    echo.
    pause
    goto :eof
  ) else (
    set Community=!CommunityPrompt!
  )
)

set ExistingCommunities=0
set ExistingManagers=0
set ChangesMade=0

echo.
echo The SNMP service will be configured as follows:
echo.
echo 	Community: %Community%
echo.
echo 	Accepted hosts:
for %%a in (%AcceptedHosts%) do echo 		- %%~a
echo.
echo 	Trap destinations:
for %%a in (%TrapDestinations%) do echo 		- %%~a
echo.
set Confirm=n
set /p Confirm=Continue [y/N]? 
if /i not "%Confirm%"=="y" goto :eof
echo.

echo Configuring Community ...
echo.
	
REM Determine if there are any existing communities
for /f "tokens=1,3*" %%a in ('reg.exe query "%SNMPKey%\ValidCommunities" ^| find /i "REG_DWORD"') do (
  set ExistingCommunities=1
  echo		Existing community found: %%a
)	
reg.exe query "%SNMPKey%\ValidCommunities" /v %Community% >NUL 2>&1
if %errorlevel% equ 0 (
  echo			Community %Community% exists - do nothing
) else (
  echo		Community %Community% does not exist - add the key as READONLY
  reg.exe add "%SNMPKey%\ValidCommunities" /v "%Community%" /t REG_DWORD /d %ACCESS_READONLY% /f
  set ChangesMade=1
)

echo.
echo Configuring Accepted Hosts ...
for /f "tokens=2,3*" %%a in ('reg.exe query "%SNMPKey%\PermittedManagers" ^| find /i "REG_SZ"') do (
  set ExistingManagers=1
  set AcceptedHosts[%%b]=%%a
)

REM If there were no existing communities (aka we are setting up the very first community)
REM Or if there were existing communities and also existing permitted managers
REM Then we will add the EM7 IP's to the list of permitted managers.
REM If there were existing communities and no permitted managers then server was set to 
REM "Accept SNMP packets from any host" and adding EM7 IPs will lock down the list of managers
REM Which could break existing monitoring.

set AddPermittedManagers=0

if %ExistingCommunities% equ 0 (
  set AddPermittedManagers=1
) else (
  if !ExistingManagers! equ 1 (
    set AddPermittedManagers=1
  )
)


if %AddPermittedManagers% equ 1 (
  for %%a in (%AcceptedHosts%) do (
    echo		- %%~a ...
    if defined AcceptedHosts[%%~a] (
      echo			... already present
    ) else (
      call :GetFreeIndex
      reg.exe add "%SNMPKey%\PermittedManagers" /v "!Index!" /t REG_SZ /d "%%~a" /f
      set ChangesMade=1
    )
  )
) else (
  echo.
  echo There were existing communities but not existing restrictions on SNMP traffic.
  echo.
  echo Not adding EM7 IP restrictions since that could break existing monitoring
  echo which relied upon the setting "Accept SNMP packets from any host"
)

echo.
echo Configuring Trap Community...
echo.

REM Does Trap community already exist?
reg.exe query "%SNMPKey%\TrapConfiguration\%Community%" >NUL 2>&1
if %errorlevel% equ 0 (
  echo		Trap Community %Community% exists - do nothing
) else (
  echo		Trap Community %Community% does not exist - add the key
  reg.exe add "%SNMPKey%\TrapConfiguration\%Community%" /f
  set ChangesMade=1
)

echo.
echo Configuring Trap Destinations...
echo.

for /f "tokens=2,3*" %%a in ('reg.exe query "%SNMPKey%\TrapConfiguration\%Community%" ^| find /i "REG_SZ"') do (
  set TrapDestinations[%%b]=%%a
)

for %%a in (%TrapDestinations%) do (
  echo		Destination - %%~a ...
  if defined TrapDestinations[%%~a] (
    echo			... already present
  ) else (
    call :GetFreeIndex
    reg.exe add "%SNMPKey%\TrapConfiguration\%Community%" /v "!Index!" /t REG_SZ /d "%%~a" /f
    reg.exe delete "%SNMPKey%\TrapConfiguration\%Community%" /ve /f >NUL 2>&1
  )
)

echo.
REM If any changes were made restart SNMP Service
if %ChangesMade% equ 1 (
  echo Restarting SNMP service ...
  echo.
  net stop SNMP
  net start SNMP
) else (
  echo No changes made. SNMP service will not be restarted.
)

echo.
echo Script Complete.
pause

goto :eof


:GetFreeIndex
set /a Index = 1

:Loop
reg.exe query "%SNMPKey%\PermittedManagers" /v "%Index%" >NUL 2>&1
if errorlevel 1 goto :eof
set /a Index += 1
goto Loop

:Init
set SNMPKey=HKLM\SYSTEM\CurrentControlSet\Services\SNMP\Parameters

set /a ACCESS_NONE =		0x0001 
set /a ACCESS_NOTIFY =		0x0002 
set /a ACCESS_READONLY =	0x0004 
set /a ACCESS_READWRITE =	0x0008 
set /a ACCESS_READCREATE = 	0x0010

set host=%COMPUTERNAME%

goto :eof
pause