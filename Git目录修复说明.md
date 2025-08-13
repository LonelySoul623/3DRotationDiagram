# Git目录修复说明

## 问题分析

您的项目结构：
```
WORKSPACE (D:\jenkins\workspace\workspace\bpc_xr_innovation13340)
├── pj_xr_holographic (PROJECT_PATH)
│   ├── .git          ← Git仓库在这里
│   ├── Assets/
│   └── Library/
└── origin/           ← 构建输出目录
```

**原始问题**：脚本在`WORKSPACE`目录下查找`.git`，但实际Git仓库在`PROJECT_PATH`目录下。

## 修复内容

### 1. Git仓库检测逻辑
```batch
# 修复前
if exist ".git" (

# 修复后  
if exist "%PROJECT_PATH%\.git" (
```

### 2. 目录切换
```batch
# 新增：切换到正确的Git目录
pushd "%PROJECT_PATH%"
# ... Git操作 ...
popd  # 返回原目录
```

### 3. 兼容性处理
如果在项目路径中没找到Git仓库，会回退检查工作空间根目录，确保不同项目结构的兼容性。

## 修复效果

### 修复前的日志
```
[INFO] 开始智能代码同步...
[WARN] 非Git仓库，跳过代码同步
```

### 修复后的预期日志
```
[INFO] 开始智能代码同步...
[DEBUG] Git仓库位置: D:\jenkins\workspace\workspace\bpc_xr_innovation13340\pj_xr_holographic
[DEBUG] 正在获取远程分支信息: your_branch
[DEBUG] 本地commit: abc123...
[DEBUG] 远程commit: def456...
[INFO] 检测到代码变更，执行同步...
```

## 验证步骤

1. **检查Git仓库位置**：
   ```batch
   dir "%PROJECT_PATH%\.git"
   ```

2. **手动测试Git命令**：
   ```batch
   cd "%PROJECT_PATH%"
   git status
   git log --oneline -1
   ```

3. **运行修复后的构建脚本**，观察日志输出

## 额外优化建议

如果您的Jenkins工作空间结构经常变化，可以考虑添加更智能的Git仓库检测：

```batch
:: 智能检测Git仓库位置
set "GIT_REPO_PATH="
if exist "%PROJECT_PATH%\.git" (
    set "GIT_REPO_PATH=%PROJECT_PATH%"
) else if exist "%WORKSPACE%\.git" (
    set "GIT_REPO_PATH=%WORKSPACE%"
) else (
    for /d %%d in ("%WORKSPACE%\*") do (
        if exist "%%d\.git" (
            set "GIT_REPO_PATH=%%d"
            goto :found_git
        )
    )
)
:found_git
```

这样可以自动适应不同的项目结构。