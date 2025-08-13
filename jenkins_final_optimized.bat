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

:: ==== 调试信息输出 ====
echo [DEBUG] 工作目录: %WORKSPACE%
echo [DEBUG] 项目路径: %PROJECT_PATH%
echo [DEBUG] 输出目录: %RESULT_DIR%
echo [DEBUG] 缓存目录: %CACHE_DIR%

:: ==== 强制分支同步 ====
echo [INFO] ===== 强制分支同步检查 =====
if exist "%PROJECT_PATH%\.git" (
    pushd "%PROJECT_PATH%"
    
    echo [DEBUG] 目标分支: %BRANCH%
    echo [DEBUG] 当前Git状态:
    git branch -v
    
    :: 获取远程分支最新信息
    echo [INFO] 获取远程分支信息: %BRANCH%
    git fetch origin %BRANCH% --depth=10 2>nul
    
    :: 强制切换到目标分支的最新状态
    echo [INFO] 强制切换到分支: %BRANCH%
    git checkout -B %BRANCH% origin/%BRANCH% 2>nul
    
    :: 验证切换结果
    for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%i"
    echo [INFO] 已切换到分支: !CURRENT_BRANCH!
    
    :: 如果仍然是detached HEAD，尝试创建本地分支
    git branch | findstr "HEAD detached" >nul
    if !errorlevel! equ 0 (
        echo [WARN] 仍处于detached HEAD状态，创建本地分支...
        git checkout -b %BRANCH% 2>nul
        for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%i"
        echo [INFO] 创建并切换到分支: !CURRENT_BRANCH!
    )
    
    :: 显示最新commit信息验证
    echo [DEBUG] 当前commit信息:
    git log --oneline -1
    
    :: 获取当前commit hash用于构建标识
    for /f "tokens=*" %%i in ('git rev-parse HEAD 2^>nul') do set "ACTUAL_COMMIT=%%i"
    echo [DEBUG] 实际使用的commit: !ACTUAL_COMMIT!
    
    popd
    
) else (
    echo [ERROR] Git仓库不存在: %PROJECT_PATH%\.git
    exit /b 1
)

echo [INFO] ===== 分支同步完成 =====

:: ==== 精简的Unity缓存清理策略 ====
echo [INFO] ===== 执行精简Unity缓存清理 =====

:: 1. 始终清理脚本程序集（确保代码更新生效）
if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
    echo [INFO] 清理脚本程序集缓存...
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
) else (
    echo [DEBUG] ScriptAssemblies目录不存在
)

:: 2. 条件清理SourceAssetDB（如果存在，Unity 2019及以前版本）
if exist "%PROJECT_PATH%\Library\SourceAssetDB" (
    echo [INFO] 清理源资源数据库缓存...
    rmdir /s /q "%PROJECT_PATH%\Library\SourceAssetDB" 2>nul
) else (
    echo [DEBUG] SourceAssetDB目录不存在（正常，Unity 2021+ 版本）
)

:: 3. 清理Unity临时文件（安全操作）
if exist "%PROJECT_PATH%\Temp" (
    echo [INFO] 清理Unity临时文件...
    rmdir /s /q "%PROJECT_PATH%\Temp" 2>nul
) else (
    echo [DEBUG] Temp目录不存在
)

:: 4. 保留以下重要缓存（保持构建性能）：
echo [DEBUG] 保留以下缓存以优化性能：
echo [DEBUG] - ShaderCache (Shader编译缓存，重建耗时)
echo [DEBUG] - ArtifactDB (构建产物缓存，重建耗时)
echo [DEBUG] - metadata (资源元数据，包含重要引用)

echo [INFO] ===== Unity缓存清理完成 =====

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

:: ==== 增量构建检测（使用实际commit）====
set "BUILD_HASH_FILE=%CACHE_DIR%\last_build_hash.txt"
set "CURRENT_HASH="

:: 使用实际的commit hash
if defined ACTUAL_COMMIT (
    set "CURRENT_HASH=%ACTUAL_COMMIT%_%VERSION%"
    echo [DEBUG] 使用实际commit生成Hash: %ACTUAL_COMMIT%
) else (
    :: 从项目目录重新获取Git信息
    pushd "%PROJECT_PATH%"
    for /f "tokens=*" %%i in ('git rev-parse HEAD 2^>nul') do set "GIT_HASH=%%i"
    popd
    set "CURRENT_HASH=!GIT_HASH!_%VERSION%"
    echo [DEBUG] 重新获取Git信息: !GIT_HASH!
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
            
            :: 显示缓存构建信息
            echo [CACHE] ================================
            echo [CACHE] 使用缓存构建结果
            echo [CACHE] 分支: %BRANCH% (实际: %CURRENT_BRANCH%)
            echo [CACHE] Commit: %ACTUAL_COMMIT%
            echo [CACHE] 版本: %VERSION%
            echo [CACHE] 输出: %RESULT_DIR%\Holo.exe
            echo [CACHE] ================================
            
            exit /b 0
        ) else (
            echo [DEBUG] Hash匹配但exe文件不存在，继续构建
        )
    ) else (
        echo [DEBUG] Hash不匹配，需要重新构建
        echo [DEBUG] 旧Hash: !LAST_HASH!
        echo [DEBUG] 新Hash: %CURRENT_HASH%
    )
) else (
    echo [DEBUG] 首次构建或缓存文件不存在
)

:: ==== 优化的Unity构建命令 ====
echo [INFO] ===== 开始Unity构建 =====
echo [INFO] 输出目录: %RESULT_DIR%

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
  -refreshAssets ^
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
        echo [ERROR] === 完整日志文件: %WORKSPACE%\unity_build.log ===
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
echo [DEBUG] 已保存构建Hash用于下次增量构建: %CURRENT_HASH%

:: ==== 构建成功信息 ====
echo [SUCCESS] 构建成功: %RESULT_DIR%\Holo.exe

:: 显示构建产物信息
if exist "%RESULT_DIR%\Holo.exe" (
    for %%F in ("%RESULT_DIR%\Holo.exe") do (
        set /a FILE_SIZE_MB=%%~zF/1024/1024
        echo [INFO] 构建产物大小: %%~zF 字节 (~!FILE_SIZE_MB! MB)
    )
)

:: ==== 最终验证信息 ====
echo [VERIFICATION] ================================
echo [VERIFICATION] 构建验证信息
echo [VERIFICATION] 目标分支: %BRANCH%
echo [VERIFICATION] 实际分支: %CURRENT_BRANCH%
echo [VERIFICATION] 使用commit: %ACTUAL_COMMIT%
echo [VERIFICATION] 构建Hash: %CURRENT_HASH%
echo [VERIFICATION] 输出文件: %RESULT_DIR%\Holo.exe
echo [VERIFICATION] Unity版本: 2021.2.8f1c1
echo [VERIFICATION] ================================

echo [INFO] 构建完成，总用时从 %BUILD_START_TIME% 到 %BUILD_END_TIME%

:: ==== 性能统计 ====
echo [PERFORMANCE] ================================
echo [PERFORMANCE] 构建性能统计
echo [PERFORMANCE] 项目: %PROJECT_PATH%
echo [PERFORMANCE] 分支: %BRANCH% (实际: %CURRENT_BRANCH%)
echo [PERFORMANCE] 版本: %VERSION%
echo [PERFORMANCE] 输出: %RESULT_DIR%\Holo.exe
echo [PERFORMANCE] 缓存策略: 精简清理（仅ScriptAssemblies + Temp）
echo [PERFORMANCE] ================================