# Unity Jenkins构建优化指南

## 当前问题分析
- **构建时间**: 20分钟 → 目标: 5-10分钟
- **主要瓶颈**: Git同步、Unity编译、文件IO操作

## 优化策略概览

### 1. Git代码同步优化 (预计节省: 2-5分钟)

#### 智能同步策略
```bash
# 原始方式：每次都完整同步
git fetch origin %BRANCH%
git reset --hard origin/%BRANCH%

# 优化方式：检查差异后再同步
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/%BRANCH%)
if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    # 只在有变化时同步
    git checkout -f %BRANCH%
    git reset --hard origin/%BRANCH%
fi
```

#### 额外优化
- 使用浅克隆: `git fetch --depth=1`
- 如果使用Git LFS，设置 `GIT_LFS_SKIP_SMUDGE=1`

### 2. Unity构建参数优化 (预计节省: 3-8分钟)

#### 新增性能参数
```bash
# 原始Unity命令
Unity.exe -batchmode -quit -projectPath "%PROJECT_PATH%" -executeMethod BuildMethod

# 优化后的Unity命令
Unity.exe ^
  -batchmode ^
  -quit ^
  -nographics ^                    # 不启动图形界面，节省GPU资源
  -buildTarget Win64 ^             # 明确指定构建目标
  -projectPath "%PROJECT_PATH%" ^
  -executeMethod BuildMethod ^
  -cacheServerEndpoint none ^      # 禁用缓存服务器（本地构建）
  -buildCacheVersion 1 ^           # 启用构建缓存版本控制
  -enableCacheServer false         # 确保不使用外部缓存服务器
```

#### 环境变量优化
```bash
set UNITY_MIXED_CALLSTACK=1
set UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
```

### 3. 增量构建策略 (预计节省: 5-15分钟)

#### 构建状态缓存
```bash
# 计算当前项目状态hash
CURRENT_HASH=%REMOTE_COMMIT%_%FILE_COUNT%_%VERSION%

# 检查是否需要重新构建
if exist "%BUILD_HASH_FILE%" (
    set /p LAST_HASH=<"%BUILD_HASH_FILE%"
    if "%CURRENT_HASH%"=="!LAST_HASH!" (
        if exist "%RESULT_DIR%\Holo.exe" (
            echo [INFO] 使用缓存构建结果
            exit /b 0
        )
    )
)
```

#### Unity Library缓存优化
```bash
# 只在代码变化时清理特定缓存
if "%CODE_CHANGED%"=="true" (
    if exist "%PROJECT_PATH%\Library\ScriptAssemblies" (
        rmdir /s /q "%PROJECT_PATH%\Library\ScriptAssemblies"
    )
)
```

### 4. 并行处理优化 (预计节省: 1-3分钟)

#### Jenkins Pipeline并行阶段
```groovy
stage('Preparation') {
    parallel {
        stage('Environment Check') { /* 环境检查 */ }
        stage('Cache Setup') { /* 缓存设置 */ }
    }
}

stage('Post Processing') {
    parallel {
        stage('Archive Results') { /* 归档结果 */ }
        stage('Cleanup') { /* 清理工作 */ }
    }
}
```

## 实施步骤

### 步骤1：备份当前配置
```bash
# 备份当前批处理文件
copy your_current_build.bat your_current_build.bat.backup
```

### 步骤2：应用优化脚本
1. 使用提供的 `optimized_unity_build.bat`
2. 根据你的实际路径调整以下变量：
   ```bash
   set "WORKSPACE=D:\jenkins\workspace\workspace\bpc_xr_innovation13340"
   set "UNITY_PATH=D:\Unity Hub\Editor\2021.2.8f1c1\Editor\Unity.exe"
   set "PROJECT_PATH=%WORKSPACE%\pj_xr_holographic"
   ```

### 步骤3：Jenkins配置优化
1. 升级到Pipeline方式（推荐使用提供的 `Jenkinsfile.optimized`）
2. 或者在现有Job中替换批处理命令

### 步骤4：硬件和环境优化

#### 构建机器优化
- **CPU**: 至少8核，推荐16核以上
- **内存**: 至少16GB，推荐32GB
- **存储**: 使用SSD，确保足够的临时空间（至少50GB）
- **网络**: 稳定的Git仓库连接

#### Jenkins节点配置
```groovy
// Jenkins节点标签配置
node {
    label 'unity-build-agent && windows && ssd'
}

// 环境变量优化
environment {
    JENKINS_NODE_COOKIE = 'dontKillMe'  // 防止进程被杀死
    BUILD_TIMEOUT = '30'                // 构建超时时间
}
```

### 步骤5：Unity项目优化

#### Project Settings优化
1. **Player Settings**:
   - 禁用不必要的图形API
   - 减少纹理质量设置（构建时）
   - 关闭调试符号生成

2. **Build Settings**:
   - 使用IL2CPP而不是Mono（更快的启动时间）
   - 启用"Development Build"进行测试构建

3. **Editor Settings**:
   ```csharp
   // 在构建脚本中添加
   EditorUserBuildSettings.development = false;
   EditorUserBuildSettings.allowDebugging = false;
   PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.IL2CPP);
   ```

## 监控和测量

### 构建时间监控
```bash
# 在脚本开始和结束添加时间戳
echo [INFO] 构建开始时间: %TIME%
# ... 构建过程 ...
echo [INFO] 构建完成时间: %TIME%
```

### 分阶段时间测量
```bash
set START_TIME=%TIME%
# Git同步
set GIT_TIME=%TIME%
# Unity构建
set BUILD_TIME=%TIME%
# 后处理
set END_TIME=%TIME%

echo [METRICS] Git同步用时: [计算时间差]
echo [METRICS] Unity构建用时: [计算时间差]
echo [METRICS] 总用时: [计算时间差]
```

## 预期效果

| 优化项目 | 原始时间 | 优化后时间 | 节省时间 |
|---------|---------|-----------|---------|
| Git同步 | 2-3分钟 | 0.5-1分钟 | 1.5-2分钟 |
| Unity编译 | 15-16分钟 | 8-10分钟 | 5-8分钟 |
| 文件操作 | 1-2分钟 | 0.5分钟 | 0.5-1.5分钟 |
| **总计** | **20分钟** | **9-12分钟** | **7-11分钟** |

## 故障排除

### 常见问题
1. **缓存失效**: 检查 `.unity_cache` 目录权限
2. **Git同步失败**: 验证网络连接和凭据
3. **Unity构建失败**: 检查Unity版本和项目兼容性

### 调试命令
```bash
# 检查Git状态
git status
git log --oneline -5

# 检查Unity进程
tasklist | findstr Unity

# 检查磁盘空间
dir /-c %WORKSPACE%
```

## 进一步优化建议

### 长期优化策略
1. **分布式构建**: 使用Jenkins分布式节点
2. **缓存服务器**: 搭建Unity缓存服务器
3. **增量构建**: 实施更精细的增量构建检测
4. **并行构建**: 多平台并行构建

### Unity Cloud Build
考虑迁移到Unity Cloud Build，可以获得：
- 专业的构建环境
- 自动缓存优化
- 多平台并行构建
- 构建时间通常在5-10分钟

## 联系支持
如果需要进一步的配置帮助或遇到问题，请提供：
1. Jenkins版本信息
2. Unity版本信息
3. 构建失败日志
4. 当前硬件配置信息