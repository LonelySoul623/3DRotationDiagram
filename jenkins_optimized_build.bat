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
echo [DEBUG] 项目路径: %PROJECT_PATH%
echo [DEBUG] 输出目录: %RESULT_DIR%
echo [DEBUG] 缓存目录: %CACHE_DIR%

:: ==== Jenkins已处理Git同步，跳过Git操作 ====
echo [INFO] Jenkins已完成代码同步，开始构建优化检查...
set "CODE_CHANGED=true"

:: ==== 初始化目录 ====
if not exist "%WORKSPACE%\origin" mkdir "%WORKSPACE%\origin" >nul 2>&1
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%" >nul 2>&1
if not exist "%RESULT_DIR%" mkdir "%RESULT_DIR%" >nul 2>&1

if not exist "%RESULT_DIR%" (
    echo [ERROR] 无法创建输出目录: %RESULT_DIR%
    exit /b 1
)

:: ==== 验证Unity项目 ====
if not exist "%PROJECT_PATH%\Assets" (
    echo [ERROR] Unity项目路径无效: %PROJECT_PATH%
    dir /b "%WORKSPACE%"
    exit /b 1
)

:: ==== 增量构建检测（基于Jenkins提供的Git信息）====
set "BUILD_HASH_FILE=%CACHE_DIR%\last_build_hash.txt"
set "CURRENT_HASH="

:: 尝试从Jenkins环境变量获取Git信息
if defined GIT_COMMIT (
    echo [DEBUG] 使用Jenkins Git信息: %GIT_COMMIT%
    set "CURRENT_HASH=%GIT_COMMIT%_%VERSION%"
) else (
    :: 从项目目录获取Git信息
    if exist "%PROJECT_PATH%\.git" (
        pushd "%PROJECT_PATH%"
        for /f "tokens=*" %%i in ('git rev-parse HEAD 2^>nul') do set "GIT_HASH=%%i"
        popd
        set "CURRENT_HASH=!GIT_HASH!_%VERSION%"
        echo [DEBUG] 从项目获取Git信息: !GIT_HASH!
    ) else (
        :: 使用文件统计作为fallback
        for /f "tokens=*" %%i in ('dir /s /b /a-d "%PROJECT_PATH%\Assets\*.cs" "%PROJECT_PATH%\Assets\*.prefab" "%PROJECT_PATH%\Assets\*.scene" 2^>nul ^| find /c /v ""') do set "FILE_COUNT=%%i"
        set "CURRENT_HASH=%BRANCH%_%FILE_COUNT%_%VERSION%"
        echo [DEBUG] 使用文件统计生成Hash: !FILE_COUNT! 个文件
    )
)

echo [DEBUG] 当前构建Hash: %CURRENT_HASH%

:: 检查是否需要重新构建
if exist "%BUILD_HASH_FILE%" (
    set /p LAST_HASH=<"%BUILD_HASH_FILE%"
    echo [DEBUG] 上次构建Hash: !LAST_HASH!
    if "%CURRENT_HASH%"=="!LAST_HASH!" (
        if exist "%RESULT_DIR%\Holo.exe" (
            echo [INFO] 检测到相同构建状态，使用缓存构建结果
            echo [SUCCESS] 构建成功（使用缓存）: %RESULT_DIR%\Holo.exe
            exit /b 0
        ) else (
            echo [DEBUG] Hash匹配但exe文件不存在，继续构建
        )
    ) else (
        echo [DEBUG] Hash不匹配，需要重新构建
    )
) else (
    echo [DEBUG] 首次构建或缓存文件不存在
)

:: ==== Unity构建性能优化 ====
echo [INFO] 开始Unity构建优化...

:: 清理特定缓存以提高构建效率
if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
    echo [INFO] 清理脚本程序集缓存以确保最新代码...
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
)

:: 清理旧的临时文件
if exist "%PROJECT_PATH%\Temp" (
    echo [INFO] 清理Unity临时文件...
    rmdir /s /q "%PROJECT_PATH%\Temp" 2>nul
)

:: ==== 优化的Unity构建命令 ====
echo [INFO] 开始Unity构建，输出目录: %RESULT_DIR%

:: 设置Unity环境变量以优化性能
set UNITY_MIXED_CALLSTACK=1
set UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
set UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1

:: 记录构建开始时间
set BUILD_START_TIME=%TIME%
echo [TIMING] Unity构建开始时间: %BUILD_START_TIME%

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
  -buildCacheVersion 1

:: 记录构建结束时间
set BUILD_END_TIME=%TIME%
echo [TIMING] Unity构建结束时间: %BUILD_END_TIME%

:: ==== 检查构建结果 ====
if %errorlevel% neq 0 (
    echo [ERROR] Unity构建失败！详见日志:
    if exist "%WORKSPACE%\unity_build.log" (
        echo [ERROR] === 构建错误摘要 ===
        type "%WORKSPACE%\unity_build.log" | findstr /i "error fail exception"
        echo [ERROR] === 日志文件位置: %WORKSPACE%\unity_build.log ===
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
echo [DEBUG] 已保存构建Hash用于下次增量构建

:: ==== 构建成功后的优化处理 ====
echo [SUCCESS] 构建成功: %RESULT_DIR%\Holo.exe

:: 显示构建产物信息
if exist "%RESULT_DIR%\Holo.exe" (
    for %%F in ("%RESULT_DIR%\Holo.exe") do (
        echo [INFO] 构建产物大小: %%~zF 字节 ^(约 %%~zF 字节^)
    )
)

:: ==== 可选：预压缩构建结果以减少后续处理时间 ====
if exist "%ZIP_PATH%" del "%ZIP_PATH%" >nul 2>&1

:: 使用PowerShell压缩（Windows内置，比外部工具快）
echo [INFO] 开始压缩构建结果...
set COMPRESS_START_TIME=%TIME%
powershell -Command "Compress-Archive -Path '%RESULT_DIR%\*' -DestinationPath '%ZIP_PATH%' -CompressionLevel Fastest" 2>nul

if exist "%ZIP_PATH%" (
    set COMPRESS_END_TIME=%TIME%
    echo [TIMING] 压缩开始时间: %COMPRESS_START_TIME%
    echo [TIMING] 压缩结束时间: %COMPRESS_END_TIME%
    echo [INFO] 构建结果已压缩: %ZIP_PATH%
    for %%F in ("%ZIP_PATH%") do (
        echo [INFO] 压缩文件大小: %%~zF 字节
    )
) else (
    echo [WARN] 压缩失败，但构建成功
)

:: ==== 清理和维护 ====
:: 保留最新5个日志文件，删除更老的
if exist "%WORKSPACE%\unity_build*.log" (
    for /f "skip=5 delims=" %%i in ('dir /b /o-d "%WORKSPACE%\unity_build*.log" 2^>nul') do (
        del "%WORKSPACE%\%%i" 2>nul
        echo [DEBUG] 清理旧日志: %%i
    )
)

:: 清理Unity临时文件
if exist "%PROJECT_PATH%\Logs" (
    for /f "skip=3 delims=" %%i in ('dir /b /o-d "%PROJECT_PATH%\Logs\*.log" 2^>nul') do (
        del "%PROJECT_PATH%\Logs\%%i" 2>nul
    )
)

echo [INFO] 构建完成，总用时从 %BUILD_START_TIME% 到 %BUILD_END_TIME%

:: ==== 性能统计 ====
echo [PERFORMANCE] ================================
echo [PERFORMANCE] 构建性能统计
echo [PERFORMANCE] 项目: %PROJECT_PATH%
echo [PERFORMANCE] 分支: %BRANCH%
echo [PERFORMANCE] 版本: %VERSION%
echo [PERFORMANCE] 输出: %RESULT_DIR%\Holo.exe
if exist "%ZIP_PATH%" (
    echo [PERFORMANCE] 压缩: %ZIP_PATH%
)
echo [PERFORMANCE] ================================