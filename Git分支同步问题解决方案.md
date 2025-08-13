# Git分支同步问题解决方案

## 问题现状

### 观察到的问题
1. **Detached HEAD**: `* (HEAD detached at f194335ab)`
2. **分支不匹配**: Jenkins要构建 `feature/830_project_optimize`，但checkout了旧commit
3. **Unity编辑器状态**: 没有反映最新的分支变化
4. **构建时间**: 仍然是1分钟，说明优化生效了，但分支问题需要解决

### 日志分析
```
Jenkins参数: feature/830_project_optimize
实际checkout: f194335abbaaa3ee62fcaecefb84628cf415e47a (develop分支的commit)
```

**问题原因**: Jenkins仍在使用develop分支的commit来构建feature分支。

## 解决方案

### 方案1: 修复Jenkins分支配置（推荐）

#### 1.1 检查Jenkins分支设置

1. **进入Jenkins作业配置**
2. **查看"源码管理" → Git配置**
3. **检查"Branches to build"设置**

当前可能的配置：
```
Branches to build: */develop
```

**需要修改为**：
```
Branches to build: ${BRANCH}
或
Branches to build: */${this_branch}
```

#### 1.2 具体操作步骤

1. **进入作业配置页面**
2. **找到"源码管理"部分**
3. **在"Branches to build"中修改**：
   - 原来: `*/develop` 或 `*/release/6.3.0`
   - 修改为: `*/${this_branch}` 或 `${BRANCH}`

4. **保存配置**

### 方案2: 在构建脚本中强制分支同步

如果无法修改Jenkins配置，在构建脚本中添加分支同步逻辑：

```batch
@echo off
setlocal EnableDelayedExpansion

:: 设置变量
set BRANCH=%this_branch%
set "PROJECT_PATH=%WORKSPACE%\pj_xr_holographic"

echo [INFO] ===== 分支同步检查 =====
echo [DEBUG] 目标分支: %BRANCH%
echo [DEBUG] 项目路径: %PROJECT_PATH%

:: 切换到项目目录并强制同步到正确分支
if exist "%PROJECT_PATH%\.git" (
    echo [INFO] 强制同步到目标分支: %BRANCH%
    pushd "%PROJECT_PATH%"
    
    :: 显示当前状态
    echo [DEBUG] 当前Git状态:
    git status --porcelain
    git branch -v
    
    :: 获取远程最新信息
    echo [INFO] 获取远程分支信息...
    git fetch origin %BRANCH% --depth=10 2>nul
    
    :: 强制切换到目标分支
    echo [INFO] 强制切换到分支: %BRANCH%
    git checkout -B %BRANCH% origin/%BRANCH% 2>nul
    
    :: 验证切换结果
    for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%i"
    echo [DEBUG] 切换后的分支: !CURRENT_BRANCH!
    
    :: 如果仍然是detached HEAD，尝试创建本地分支
    git branch | findstr "HEAD detached" >nul
    if !errorlevel! equ 0 (
        echo [WARN] 仍处于detached HEAD状态，创建本地分支...
        git checkout -b %BRANCH% 2>nul
    )
    
    :: 显示最新commit信息
    echo [DEBUG] 当前commit信息:
    git log --oneline -1
    
    popd
    
    :: 强制清理Unity缓存以确保同步
    echo [INFO] 清理Unity缓存以确保分支同步...
    if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
        rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
    )
    if exist "%PROJECT_PATH%\Library\SourceAssetDB" (
        rmdir /s /q "%PROJECT_PATH%\Library\SourceAssetDB" 2>nul
    )
    if exist "%PROJECT_PATH%\Temp" (
        rmdir /s /q "%PROJECT_PATH%\Temp" 2>nul
    )
    
) else (
    echo [ERROR] Git仓库不存在: %PROJECT_PATH%\.git
    exit /b 1
)

echo [INFO] ===== 分支同步完成 =====

:: 继续原有的构建逻辑...
```

### 方案3: Unity强制刷新

在Unity构建前添加强制刷新：

```batch
:: 在Unity构建命令中添加刷新参数
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
  -logFile "%WORKSPACE%\unity_build.log"
```

## 推荐实施方案

### 立即解决方案 (方案2)

将以下代码添加到现有的`jenkins_optimized_build.bat`脚本中，在Unity构建之前：

```batch
:: ==== 强制分支同步 ====
echo [INFO] ===== 强制分支同步检查 =====
if exist "%PROJECT_PATH%\.git" (
    pushd "%PROJECT_PATH%"
    
    echo [DEBUG] 目标分支: %BRANCH%
    echo [DEBUG] 当前Git状态:
    git branch -v
    
    :: 强制切换到目标分支
    git fetch origin %BRANCH% --depth=10 2>nul
    git checkout -B %BRANCH% origin/%BRANCH% 2>nul
    
    :: 验证结果
    for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%i"
    echo [INFO] 已切换到分支: !CURRENT_BRANCH!
    git log --oneline -1
    
    popd
    
    :: 清理Unity缓存确保同步
    if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
        echo [INFO] 清理Unity程序集缓存...
        rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
    )
)
```

### 长期解决方案 (方案1)

修改Jenkins配置中的分支设置：
1. **Branches to build**: 改为 `*/${this_branch}`
2. **确保Jenkins使用动态分支**而不是固定的develop分支

## 验证方法

修复后，检查以下内容：

### 1. Git状态验证
```bash
cd D:\jenkins\workspace\workspace\bpc_xr_innovation13340\pj_xr_holographic
git branch
git log --oneline -1
```

应该显示：
```
* feature/830_project_optimize
最新的commit信息...
```

### 2. Unity构建日志验证
构建日志中应该显示：
```
[INFO] 已切换到分支: feature/830_project_optimize
[DEBUG] 当前commit信息: xxxxx (最新commit)
```

### 3. 构建产物验证
- 打开构建的Unity项目
- 检查是否包含了目标分支的最新变更
- 验证删除的预制体确实被删除

## 性能影响

- 添加分支同步检查约增加10-30秒
- 清理Unity缓存约增加30-60秒
- 总体仍比原来的25分钟要快很多

## 总结

这个问题的根本原因是Jenkins的Git插件使用了commit hash而不是分支名进行checkout，导致了detached HEAD状态。通过强制分支同步和Unity缓存清理，可以确保构建使用正确的分支代码。