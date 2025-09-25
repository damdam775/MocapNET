@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------------------
rem MocapNET Windows build and installation helper
rem This script checks dependencies, downloads pretrained assets, configures the
rem build directory, compiles MocapNET, and finally launches the live demo.
rem It also exposes optional flows for rebuilding TensorFlow using WSL.
rem ---------------------------------------------------------------------------

set "SCRIPT_ROOT=%~dp0"
for %%I in ("%SCRIPT_ROOT%") do set "SCRIPT_ROOT=%%~fI"
cd /d "%SCRIPT_ROOT%"

if not exist "%SCRIPT_ROOT%\CMakeLists.txt" (
    echo [ERROR] Please run this script from the MocapNET repository root.
    exit /b 1
)

title MocapNET build and install helper

call :printBanner

rem Resolve a Python interpreter early; tqdm requires it.
call :ensureProgram "python" "Python.Python.3.11" "python" "Python 3"
if errorlevel 1 goto :fatal
set "PYTHON=python"

rem Ensure tqdm is available for progress output.
call :ensureTqdm
if errorlevel 1 goto :fatal

:mainMenu
echo.
echo === MocapNET build/install menu ===
echo   [1] Full install (deps + assets + build + demo)
echo   [2] Reconfigure and rebuild MocapNET only
echo   [3] Download or update pretrained assets
echo   [4] Rebuild TensorFlow C-API (via WSL)
echo   [5] Exit
choice /c 12345 /n /m "Select an option: "
set "MENU=%errorlevel%"
if "%MENU%"=="5" goto :eof
if "%MENU%"=="4" goto :tensorflowMenu
if "%MENU%"=="3" goto :downloadAssetsFlow
if "%MENU%"=="2" goto :buildOnlyFlow
if "%MENU%"=="1" goto :fullInstallFlow
goto :mainMenu

:fullInstallFlow
call :progressStep "Checking system dependencies"
call :checkDependencies
if errorlevel 1 goto :fatal

call :progressStep "Downloading MocapNET resources"
call :downloadAssets
if errorlevel 1 goto :fatal

call :progressStep "Configuring build directory"
call :configureBuild
if errorlevel 1 goto :fatal

call :progressStep "Compiling MocapNET"
call :buildMocapNET
if errorlevel 1 goto :fatal

call :progressStep "Launching MocapNET live demo"
call :launchDemo
if errorlevel 1 goto :fatal
goto :mainMenu

:buildOnlyFlow
call :progressStep "Checking system dependencies"
call :checkDependencies
if errorlevel 1 goto :fatal

call :progressStep "Configuring build directory"
call :configureBuild
if errorlevel 1 goto :fatal

call :progressStep "Compiling MocapNET"
call :buildMocapNET
if errorlevel 1 goto :fatal

echo.
echo Build complete. Launching the live demo next.
call :progressStep "Launching MocapNET live demo"
call :launchDemo
if errorlevel 1 goto :fatal
goto :mainMenu

:downloadAssetsFlow
call :progressStep "Downloading MocapNET resources"
call :downloadAssets
if errorlevel 1 goto :fatal
goto :mainMenu

:tensorflowMenu
echo.
echo === TensorFlow build options ===
echo This repository vendors a prebuilt TensorFlow C API. Building from source
echo is optional and requires a properly configured WSL Ubuntu environment with
echo Bazel, CUDA (optional) and additional prerequisites.
echo.
echo   [1] Build TensorFlow r1.15 in WSL using scripts/tensorflowBuild.sh
echo   [2] Return to main menu
choice /c 12 /n /m "Select an option: "
if errorlevel 2 goto :mainMenu

call :progressStep "Launching WSL TensorFlow build"
call :buildTensorflowWSL
if errorlevel 1 goto :fatal
goto :mainMenu


rem ===========================================================================
rem Helper subroutines
rem ===========================================================================

:printBanner
echo ------------------------------------------------------------
echo MocapNET build and installation helper for Windows
echo ------------------------------------------------------------
exit /b 0

:progressStep
set "STEP_DESC=%~1"
%PYTHON% -c "from tqdm import tqdm; import sys,time; desc=sys.argv[1]; bar=tqdm(total=32, desc=desc, leave=False); [time.sleep(0.05) for _ in range(32)]; bar.close()" "%STEP_DESC%"
exit /b 0

:ensureProgram
set "BIN_NAME=%~1"
set "WINGET_ID=%~2"
set "CHOCO_ID=%~3"
set "DISPLAY=%~4"
where %BIN_NAME% >nul 2>&1
if %errorlevel%==0 (
    echo [+] Found %DISPLAY% executable (%BIN_NAME%).
    exit /b 0
)

set "INSTALLED=0"
where winget >nul 2>&1
if %errorlevel%==0 if not "%WINGET_ID%"=="" (
    echo [*] Installing %DISPLAY% via winget...
    winget install --id "%WINGET_ID%" --source winget -e -h
    if %errorlevel%==0 (
        where %BIN_NAME% >nul 2>&1 && set "INSTALLED=1"
    )
)

if "%INSTALLED%"=="0" (
    where choco >nul 2>&1
    if %errorlevel%==0 if not "%CHOCO_ID%"=="" (
        echo [*] Installing %DISPLAY% via chocolatey...
        choco install "%CHOCO_ID%" -y
        if %errorlevel%==0 (
        where %BIN_NAME% >nul 2>&1 && set "INSTALLED=1"
        )
    )
)

if "%INSTALLED%"=="0" (
    echo [!] Unable to locate %DISPLAY% automatically. Please install it manually and re-run the script.
    exit /b 1
)

echo [+] %DISPLAY% installation completed.
exit /b 0

:ensureTqdm
%PYTHON% -m pip show tqdm >nul 2>&1
if %errorlevel%==0 (
    exit /b 0
)

echo [*] Installing Python tqdm module for progress bars...
%PYTHON% -m pip install --user --upgrade pip >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Failed to upgrade pip.
)
%PYTHON% -m pip install --user tqdm
if %errorlevel% neq 0 (
    echo [!] Could not install tqdm automatically.
    exit /b 1
)
exit /b 0

:checkDependencies
call :ensureProgram "git" "Git.Git" "git" "Git"
if errorlevel 1 exit /b 1
call :ensureProgram "cmake" "Kitware.CMake" "cmake" "CMake"
if errorlevel 1 exit /b 1
call :ensureProgram "powershell" "" "" "PowerShell"
if errorlevel 1 exit /b 1

rem Try to detect vcpkg - install locally if missing
if not exist "%SCRIPT_ROOT%\dependencies\vcpkg\vcpkg.exe" (
    echo [*] Setting up local vcpkg manifest...
    git clone https://github.com/microsoft/vcpkg "%SCRIPT_ROOT%\dependencies\vcpkg"
    if errorlevel 1 (
        echo [!] Failed to clone vcpkg repository.
        exit /b 1
    )
    call "%SCRIPT_ROOT%\dependencies\vcpkg\bootstrap-vcpkg.bat"
    if errorlevel 1 (
        echo [!] Failed to bootstrap vcpkg.
        exit /b 1
    )
)

set "VCPKG_ROOT=%SCRIPT_ROOT%\dependencies\vcpkg"
set "VCPKG_TOOLCHAIN=%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake"

rem Install OpenCV manifest for x64-windows
"%VCPKG_ROOT%\vcpkg.exe" install opencv:x64-windows
if errorlevel 1 (
    echo [!] Failed to install OpenCV via vcpkg.
    exit /b 1
)

call :findVisualStudio
if errorlevel 1 exit /b 1
exit /b 0

:findVisualStudio
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL=%%I"
)
if not defined VS_INSTALL (
    echo [!] Visual Studio with C++ workload not detected. Please install Visual Studio 2022 with "Desktop development with C++" workload.
    exit /b 1
)

set "VS_DEV_CMD=%VS_INSTALL%\Common7\Tools\VsDevCmd.bat"
if exist "%VS_DEV_CMD%" (
    call "%VS_DEV_CMD%" -arch=amd64 >nul
)
set "CMAKE_GENERATOR=Visual Studio 17 2022"
exit /b 0

:configureBuild
if not defined CMAKE_GENERATOR (
    set "CMAKE_GENERATOR=Visual Studio 17 2022"
)
set "BUILD_DIR=%SCRIPT_ROOT%\build"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

if exist "%VCPKG_TOOLCHAIN%" (
    cmake -S "%SCRIPT_ROOT%" -B "%BUILD_DIR%" -G "%CMAKE_GENERATOR%" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_TOOLCHAIN%"
) else (
    cmake -S "%SCRIPT_ROOT%" -B "%BUILD_DIR%" -G "%CMAKE_GENERATOR%" -A x64
)
if errorlevel 1 (
    echo [!] CMake configuration failed.
    exit /b 1
)
exit /b 0

:buildMocapNET
if not defined BUILD_DIR set "BUILD_DIR=%SCRIPT_ROOT%\build"
cmake --build "%BUILD_DIR%" --config Release --target MocapNET2LiveWebcamDemo
if errorlevel 1 (
    echo [!] Build failed.
    exit /b 1
)
exit /b 0

:downloadAssets
set "DATASET_ROOT=%SCRIPT_ROOT%\dataset"
if not exist "%DATASET_ROOT%" mkdir "%DATASET_ROOT%"

rem Optionally download CMU BVH dataset
if not exist "%DATASET_ROOT%\MotionCapture\READMEFIRST.txt" (
    echo.
    echo The CMU BVH dataset (~1GB download, 4GB unpacked) is optional and only
    echo required for dataset generation utilities.
    choice /c YN /n /m "Download CMU dataset? [Y/N]: "
    if errorlevel 2 (
        echo Skipping CMU dataset download.
    ) else (
        call :downloadFile "https://drive.google.com/u/3/uc?id=1Zt-MycqhMylfBUqgmW9sLBclNNxoNGqV&export=download&confirm=yes" "%DATASET_ROOT%\CMUPlusHeadMotionCapture.zip"
        if errorlevel 1 exit /b 1
        powershell -NoLogo -NoProfile -Command "Expand-Archive -LiteralPath '%DATASET_ROOT%\CMUPlusHeadMotionCapture.zip' -DestinationPath '%DATASET_ROOT%\MotionCapture' -Force"
        del "%DATASET_ROOT%\CMUPlusHeadMotionCapture.zip" >nul 2>&1
    )
)

rem Download demo video
if not exist "%SCRIPT_ROOT%\shuffle.webm" (
    call :downloadFile "http://cvrlcode.ics.forth.gr/web_share/mocapnet/shuffle.webm" "%SCRIPT_ROOT%\shuffle.webm"
    if errorlevel 1 exit /b 1
)

rem Download makehuman assets
if not exist "%DATASET_ROOT%\makehuman.tri" (
    call :downloadFile "http://cvrlcode.ics.forth.gr/web_share/mocapnet/makehuman.tri" "%DATASET_ROOT%\makehuman.tri"
    if errorlevel 1 exit /b 1
)
if not exist "%DATASET_ROOT%\makehuman.dae" (
    call :downloadFile "http://cvrlcode.ics.forth.gr/web_share/mocapnet/makehuman.dae" "%DATASET_ROOT%\makehuman.dae"
    if errorlevel 1 exit /b 1
)

rem Download combined model zip once
if not exist "%SCRIPT_ROOT%\allInOneMNET2RedistMirrorICPR2020.zip" (
    call :downloadFile "https://drive.google.com/u/3/uc?id=1GtmPWOpf3MzhqhqegaC8cS3_m3Drp6y3&export=download&confirm=yes" "%SCRIPT_ROOT%\allInOneMNET2RedistMirrorICPR2020.zip"
    if errorlevel 1 exit /b 1
    powershell -NoLogo -NoProfile -Command "Expand-Archive -LiteralPath '%SCRIPT_ROOT%\allInOneMNET2RedistMirrorICPR2020.zip' -DestinationPath '%SCRIPT_ROOT%' -Force"
)

rem Ensure neural network models exist
set "MODE_DIR=%DATASET_ROOT%\combinedModel\mocapnet2\mode5\1.0"
if not exist "%MODE_DIR%" mkdir "%MODE_DIR%"
set "MODEL_SOURCE=http://cvrlcode.ics.forth.gr/web_share/mocapnet/icpr2020"
for %%M in (categorize_lowerbody_all.pb lowerbody_left.pb upperbody_left.pb categorize_upperbody_all.pb lowerbody_right.pb upperbody_right.pb lowerbody_back.pb upperbody_back.pb lowerbody_front.pb upperbody_front.pb) do (
    if not exist "%MODE_DIR%\%%M" (
        call :downloadFile "%MODEL_SOURCE%/%%M" "%MODE_DIR%\%%M"
        if errorlevel 1 exit /b 1
    )
)

set "COMBINED_DIR=%DATASET_ROOT%\combinedModel"
if not exist "%COMBINED_DIR%" mkdir "%COMBINED_DIR%"
if not exist "%COMBINED_DIR%\openpose_model.pb" (
    call :downloadFile "http://cvrlcode.ics.forth.gr/web_share/mocapnet/combinedModel/openpose_model.pb" "%COMBINED_DIR%\openpose_model.pb"
    if errorlevel 1 exit /b 1
)
if not exist "%COMBINED_DIR%\vnect_sm_pafs_8.1k.pb" (
    call :downloadFile "http://cvrlcode.ics.forth.gr/web_share/mocapnet/combinedModel/vnect_sm_pafs_8.1k.pb" "%COMBINED_DIR%\vnect_sm_pafs_8.1k.pb"
    if errorlevel 1 exit /b 1
)
if not exist "%COMBINED_DIR%\mobnet2_tiny_vnect_sm_1.9k.pb" (
    call :downloadFile "http://cvrlcode.ics.forth.gr/web_share/mocapnet/combinedModel/mobnet2_tiny_vnect_sm_1.9k.pb" "%COMBINED_DIR%\mobnet2_tiny_vnect_sm_1.9k.pb"
    if errorlevel 1 exit /b 1
)

echo [+] Asset download complete.
exit /b 0

:downloadFile
set "URL=%~1"
set "DEST=%~2"
if exist "%DEST%" (
    echo [=] %DEST% already present. Skipping download.
    exit /b 0
)
echo [*] Downloading %URL%
powershell -NoLogo -NoProfile -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%DEST%' -UseBasicParsing"
if errorlevel 1 (
    echo [!] Failed to download %URL%
    exit /b 1
)
exit /b 0

:launchDemo
set "BUILD_DIR=%SCRIPT_ROOT%\build"
set "DEMO_EXE=%BUILD_DIR%\bin\Release\MocapNET2LiveWebcamDemo.exe"
if not exist "%DEMO_EXE%" set "DEMO_EXE=%BUILD_DIR%\Release\MocapNET2LiveWebcamDemo.exe"
if not exist "%DEMO_EXE%" set "DEMO_EXE=%BUILD_DIR%\MocapNET2LiveWebcamDemo.exe"
if not exist "%DEMO_EXE%" (
    echo [!] Could not locate MocapNET2LiveWebcamDemo.exe
    exit /b 1
)

set "DEMO_SOURCE=--from \"%SCRIPT_ROOT%shuffle.webm\" --openpose --frames 375"
if exist "%SCRIPT_ROOT%\shuffle.webm" (
    "%DEMO_EXE%" %DEMO_SOURCE%
) else (
    "%DEMO_EXE%" --from 0 --live
)
exit /b 0

:buildTensorflowWSL
where wsl >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Windows Subsystem for Linux (wsl.exe) is not available. Install WSL and Ubuntu to continue.
    exit /b 1
)
for /f "usebackq tokens=*" %%I in (`wsl wslpath "%SCRIPT_ROOT%"`) do set "WSL_ROOT=%%I"
if not defined WSL_ROOT (
    echo [!] Unable to map repository path to WSL.
    exit /b 1
)

wsl bash -lc "cd '%WSL_ROOT%' && chmod +x scripts/tensorflowBuild.sh && ./scripts/tensorflowBuild.sh"
if %errorlevel% neq 0 (
    echo [!] TensorFlow build exited with errors. Inspect the WSL console output for details.
    exit /b 1
)

echo [+] TensorFlow build completed successfully. Collect the generated archives from the WSL home directory as indicated by the script.
exit /b 0

:fatal
echo.
echo [FATAL] The build/install script encountered an unrecoverable error.
echo Please review the messages above, address the issue, and rerun build_install.bat.
exit /b 1
