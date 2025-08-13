@echo off
setlocal EnableDelayedExpansion

set BRANCH=%this_branch%
echo [CONFIRM] 构建分支: %BRANCH%

echo [DEBUG] Jenkins参数 this_branch=%this_branch%
echo [DEBUG] 映射后的 BRANCH=%BRANCH%

if "%AUTO_job_projectVersion%"=="" (
    set "AUTO_job_projectVersion=1.0.0"
    echo [WARN] 使用默认版本: %AUTO_job_projectVersion%
)

echo [CONFIRM] 构建分支: %BRANCH% 版本: %AUTO_job_projectVersion%

:: ==== 硬编码路径 ====
set "WORKSPACE=D:\jenkins\workspace\workspace\bpc_xr_innovation13340"
set "UNITY_PATH=D:\Unity Hub\Editor\2021.2.8f1c1\Editor\Unity.exe"
set "PROJECT_PATH=%WORKSPACE%\pj_xr_holographic"
set "CACHE_DIR=%WORKSPACE%\.unity_cache"
set VERSION=%AUTO_job_projectVersion%

:: ==== 动态生成输出路径 ====
set "processed_branch=%BRANCH:/=_%"
set "RESULT_DIR=%WORKSPACE%\origin\%processed_branch%_%AUTO_job_projectVersion%"
set "ZIP_PATH=%RESULT_DIR%.zip"

:: ==== 调试信息输出 ====
echo [DEBUG] 工作目录: %WORKSPACE%
echo [DEBUG] 输出目录: %RESULT_DIR%
echo [DEBUG] 缓存目录: %CACHE_DIR%
echo [DEBUG] 压缩包路径: %ZIP_PATH%

:: ==== 优化的Git同步策略 ====
echo [INFO] 开始智能代码同步...
if exist "%PROJECT_PATH%\.git" (
    echo [DEBUG] Git仓库位置: %PROJECT_PATH%
    
    :: 切换到项目目录执行Git操作
    pushd "%PROJECT_PATH%"
    
    :: 获取当前本地commit hash
    for /f "tokens=*" %%i in ('git rev-parse HEAD 2^>nul') do set "LOCAL_COMMIT=%%i"
    
    :: 先fetch获取最新远程信息（轻量级操作）
    echo [DEBUG] 正在获取远程分支信息: %BRANCH%
    git fetch origin %BRANCH% --depth=1 2>nul
    
    :: 获取远程commit hash
    for /f "tokens=*" %%i in ('git rev-parse origin/%BRANCH% 2^>nul') do set "REMOTE_COMMIT=%%i"
    
    echo [DEBUG] 本地commit: %LOCAL_COMMIT%
    echo [DEBUG] 远程commit: %REMOTE_COMMIT%
    
    if "%LOCAL_COMMIT%"=="%REMOTE_COMMIT%" (
        echo [INFO] 代码已是最新，跳过同步步骤
        set "CODE_CHANGED=false"
    ) else (
        echo [INFO] 检测到代码变更，执行同步...
        git checkout -f %BRANCH%
        git reset --hard origin/%BRANCH%
        set "CODE_CHANGED=true"
    )
    
    :: 返回原目录
    popd
) else (
    echo [WARN] 在项目路径中未找到Git仓库: %PROJECT_PATH%\.git
    echo [DEBUG] 检查是否在工作空间根目录有Git仓库...
    if exist "%WORKSPACE%\.git" (
        echo [INFO] 在工作空间根目录找到Git仓库，切换到该目录
        pushd "%WORKSPACE%"
        
        :: 获取当前本地commit hash
        for /f "tokens=*" %%i in ('git rev-parse HEAD 2^>nul') do set "LOCAL_COMMIT=%%i"
        
        :: 先fetch获取最新远程信息
        git fetch origin %BRANCH% --depth=1 2>nul
        
        :: 获取远程commit hash
        for /f "tokens=*" %%i in ('git rev-parse origin/%BRANCH% 2^>nul') do set "REMOTE_COMMIT=%%i"
        
        echo [DEBUG] 本地commit: %LOCAL_COMMIT%
        echo [DEBUG] 远程commit: %REMOTE_COMMIT%
        
        if "%LOCAL_COMMIT%"=="%REMOTE_COMMIT%" (
            echo [INFO] 代码已是最新，跳过同步步骤
            set "CODE_CHANGED=false"
        ) else (
            echo [INFO] 检测到代码变更，执行同步...
            git checkout -f %BRANCH%
            git reset --hard origin/%BRANCH%
            set "CODE_CHANGED=true"
        )
        
        popd
    ) else (
        echo [WARN] 未找到Git仓库，跳过代码同步
        set "CODE_CHANGED=true"
    )
)

:: ==== 初始化目录（强制创建） ====
if not exist "%WORKSPACE%\origin" mkdir "%WORKSPACE%\origin" >nul 2>&1
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1
if not exist "%RESULT_DIR%" mkdir "%RESULT_DIR%" >nul 2>&1

if not exist "%RESULT_DIR%" (
    echo [ERROR] 无法创建输出目录: %RESULT_DIR%
    echo [DEBUG] 当前权限:
    icacls "%WORKSPACE%" | findstr /i "SYSTEM Everyone"
    exit /b 1
)

:: ==== 验证Unity项目 ====
if not exist "%PROJECT_PATH%\Assets" (
    echo [ERROR] Unity项目路径无效: %PROJECT_PATH%
    dir /b "%WORKSPACE%"
    exit /b 1
)

:: ==== 增量构建检测 ====
set "BUILD_HASH_FILE=%CACHE_DIR%\last_build_hash.txt"
set "CURRENT_HASH="

:: 计算当前项目状态hash（基于关键文件和代码commit）
if exist "%PROJECT_PATH%\Assets" (
    :: 使用文件修改时间和大小来生成简单hash
    for /f "tokens=*" %%i in ('dir /s /b /a-d "%PROJECT_PATH%\Assets\*.cs" "%PROJECT_PATH%\Assets\*.prefab" "%PROJECT_PATH%\Assets\*.scene" 2^>nul ^| findstr /v "\.meta$" ^| wc -l 2^>nul') do set "FILE_COUNT=%%i"
    set "CURRENT_HASH=%REMOTE_COMMIT%_%FILE_COUNT%_%VERSION%"
)

if exist "%BUILD_HASH_FILE%" (
    set /p LAST_HASH=<"%BUILD_HASH_FILE%"
    if "%CURRENT_HASH%"=="!LAST_HASH!" (
        if exist "%RESULT_DIR%\Holo.exe" (
            echo [INFO] 检测到相同构建状态，使用缓存构建结果
            echo [SUCCESS] 构建成功（使用缓存）: %RESULT_DIR%\Holo.exe
            exit /b 0
        )
    )
)

:: ==== 清理旧的Library缓存（如果代码有变化） ====
if "%CODE_CHANGED%"=="true" (
    if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
        echo [INFO] 代码变更，清理脚本程序集缓存...
        rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
    )
)

:: ==== 优化的Unity构建命令 ====
echo [INFO] 开始Unity构建，输出目录: %RESULT_DIR%

:: 设置Unity环境变量以优化性能
set UNITY_MIXED_CALLSTACK=1
set UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30

"%UNITY_PATH%" ^
  -batchmode ^
  -quit ^
  -buildTarget Win64 ^
  -projectPath "%PROJECT_PATH%" ^
  -executeMethod BuilldPlayerTools.BuildPlayer ^
  -productName=Holo ^
  -version=%VERSION% ^
  -prefixDir="%RESULT_DIR%" ^
  -logFile "%WORKSPACE%\unity_build.log" ^
  -cacheServerEndpoint none ^
  -buildCacheVersion 1 ^
  -enableCacheServer false

:: ==== 检查构建结果 ====
if %errorlevel% neq 0 (
    echo [ERROR] Unity构建失败！详见日志:
    if exist "%WORKSPACE%\unity_build.log" (
        type "%WORKSPACE%\unity_build.log" | findstr /i "error fail exception"
    )
    exit /b 1
)

if not exist "%RESULT_DIR%\Holo.exe" (
    echo [ERROR] 未生成输出文件: %RESULT_DIR%\Holo.exe
    echo [DEBUG] 输出目录内容:
    dir /b "%RESULT_DIR%" 2>nul
    exit /b 1
)

:: ==== 保存构建hash以供下次增量构建使用 ====
echo %CURRENT_HASH% > "%BUILD_HASH_FILE%"

:: ==== 可选：压缩构建结果以减少网络传输 ====
if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1

:: 使用PowerShell压缩（Windows内置，比外部工具快）
powershell -Command "Compress-Archive -Path '%RESULT_DIR%\*' -DestinationPath '%ZIP_PATH%' -CompressionLevel Fastest" 2>nul

if exist "%ZIP_PATH%" (
    echo [INFO] 构建结果已压缩: %ZIP_PATH%
)

echo [SUCCESS] 构建成功: %RESULT_DIR%\Holo.exe

:: ==== 清理临时文件 ====
if exist "%WORKSPACE%\unity_build.log" (
    :: 保留最近5个日志文件
    for /f "skip=5 delims=" %%i in ('dir /b /o-d "%WORKSPACE%\unity_build*.log" 2^>nul') do del "%WORKSPACE%\%%i" 2>nul
)

echo [INFO] 构建完成，总用时: %TIME%