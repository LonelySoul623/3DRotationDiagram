# Unity Library目录缓存清理策略

## Unity Library目录结构分析

### 🔍 **核心缓存目录**

```
Library/
├── ScriptAssemblies/          ← **需要清理** (代码编译缓存)
├── SourceAssetDB/             ← **可能不存在** (资源数据库，新版本Unity可能没有)
├── ArtifactDB                 ← **保留** (构建产物数据库)
├── AssetImportState           ← **保留** (资源导入状态)
├── metadata/                  ← **保留** (资源元数据)
├── CurrentLayout-default.dwlt ← **保留** (编辑器布局)
├── LastSceneManagerSetup.txt  ← **保留** (场景管理器设置)
├── PlayerDataCache/           ← **保留** (播放器数据缓存)
├── ShaderCache/               ← **保留** (Shader缓存，重新生成很慢)
├── ApiUpdaterCheck.txt        ← **保留** (API更新检查)
└── ...其他系统文件
```

## 清理策略分析

### ✅ **需要清理的目录**

#### 1. ScriptAssemblies/ 
- **作用**: 存储编译后的C#程序集
- **为什么要清理**: 确保使用最新的代码变更
- **影响**: 代码更新、新增脚本、删除脚本
- **重建成本**: 低（几秒到几分钟）

#### 2. SourceAssetDB/ (如果存在)
- **作用**: 资源数据库缓存（Unity 2019及之前版本）
- **为什么要清理**: 确保资源变更被正确识别
- **影响**: 新增/删除资源、修改资源
- **重建成本**: 中等（几分钟）

### 🚫 **不应该清理的目录**

#### 1. ShaderCache/
- **作用**: 编译后的Shader缓存
- **为什么保留**: 重新编译Shader非常耗时（5-15分钟）
- **风险**: 清理后首次构建会显著变慢

#### 2. ArtifactDB
- **作用**: 资源处理结果缓存
- **为什么保留**: 重新处理所有资源非常耗时
- **风险**: 清理后可能导致10-20分钟的额外处理时间

#### 3. metadata/
- **作用**: 资源元数据和GUID映射
- **为什么保留**: 包含资源引用关系
- **风险**: 清理可能导致资源引用丢失

## 针对不同变更类型的策略

### 📝 **代码变更**
```batch
:: 只清理代码相关缓存
if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies"
)
```

### 🎨 **资源变更**
```batch
:: 清理代码和资源数据库
if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies"
)
if exist "%PROJECT_PATH%\Library\SourceAssetDB" (
    rmdir /s /q "%PROJECT_PATH%\Library\SourceAssetDB"
)
```

### 🔧 **插件变更**
```batch
:: 清理代码和导入状态
if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies"
)
if exist "%PROJECT_PATH%\Library\AssetImportState" (
    rmdir /s /q "%PROJECT_PATH%\Library\AssetImportState"
)
```

## 智能清理策略

### 基于Git变更检测的清理

```batch
:: 检测代码文件变更
git diff --name-only HEAD~1 HEAD | findstr "\.cs$" >nul
if !errorlevel! equ 0 (
    echo [INFO] 检测到代码变更，清理脚本程序集...
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
)

:: 检测资源文件变更
git diff --name-only HEAD~1 HEAD | findstr /E "\.prefab$ \.asset$ \.unity$ \.mat$" >nul
if !errorlevel! equ 0 (
    echo [INFO] 检测到资源变更，清理资源数据库...
    rmdir /s /q "%PROJECT_PATH%\Library\SourceAssetDB" 2>nul
)

:: 检测插件变更
git diff --name-only HEAD~1 HEAD | findstr "Packages\|\.dll$" >nul
if !errorlevel! equ 0 (
    echo [INFO] 检测到插件变更，清理导入状态...
    rmdir /s /q "%PROJECT_PATH%\Library\AssetImportState" 2>nul
)
```

## 保守安全策略（推荐）

考虑到构建的可靠性，建议使用保守策略：

```batch
:: ==== 安全的Unity缓存清理 ====
echo [INFO] 执行安全的Unity缓存清理...

:: 1. 始终清理脚本程序集（确保代码更新）
if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
    echo [INFO] 清理脚本程序集缓存...
    rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies" 2>nul
)

:: 2. 只在存在时清理SourceAssetDB（老版本Unity）
if exist "%PROJECT_PATH%\Library\SourceAssetDB" (
    echo [INFO] 清理源资源数据库...
    rmdir /s /q "%PROJECT_PATH%\Library\SourceAssetDB" 2>nul
) else (
    echo [DEBUG] SourceAssetDB目录不存在，跳过清理
)

:: 3. 清理临时文件（安全操作）
if exist "%PROJECT_PATH%\Temp" (
    echo [INFO] 清理Unity临时文件...
    rmdir /s /q "%PROJECT_PATH%\Temp" 2>nul
)

:: 4. 不清理以下目录（保持性能）：
:: - ShaderCache (重建耗时)
:: - ArtifactDB (重建耗时)
:: - metadata (包含重要引用信息)
```

## Unity版本差异

### Unity 2021.x (您的版本)
- **SourceAssetDB**: 可能不存在或位置不同
- **ArtifactDB**: 更重要，不应清理
- **Library/Bee**: 新的构建系统缓存，通常不需要清理

### 检测方式
```batch
:: 检查Unity版本特定的缓存
if exist "%PROJECT_PATH%\Library\Bee" (
    echo [DEBUG] 检测到Unity 2021+ Bee构建系统
)
```

## 最佳实践建议

### ✅ **推荐的清理策略**

1. **始终清理**: `ScriptAssemblies/` 和 `Temp/`
2. **条件清理**: `SourceAssetDB/`（如果存在）
3. **保留**: `ShaderCache/`, `ArtifactDB`, `metadata/`

### 🔄 **Unity刷新参数**

在Unity构建命令中添加 `-refreshAssets` 参数更安全：

```batch
"%UNITY_PATH%" ^
  -batchmode ^
  -quit ^
  -refreshAssets ^          # 强制刷新资源状态
  -buildTarget Win64 ^
  -projectPath "%PROJECT_PATH%" ^
  -executeMethod BuilldPlayerTools.BuildPlayer
```

## 验证方法

### 测试不同变更类型

1. **代码变更测试**:
   - 修改一个C#脚本
   - 运行构建，验证变更生效

2. **资源变更测试**:
   - 删除/添加预制体
   - 运行构建，验证变更生效

3. **插件变更测试**:
   - 添加/删除Package
   - 运行构建，验证变更生效

### 性能对比

- **保守清理**: 构建时间 2-3分钟
- **完全清理**: 构建时间 5-10分钟
- **不清理**: 可能出现状态不一致

## 结论

您的观察是正确的！对于Unity 2021.x：

1. **必须清理**: `ScriptAssemblies/`
2. **可选清理**: `SourceAssetDB/`（可能不存在）
3. **建议保留**: 其他所有目录

这样既能保证构建状态的正确性，又能保持较好的构建性能。