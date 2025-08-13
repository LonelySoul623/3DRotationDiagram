# Jenkins Unity构建优化建议

## 当前情况分析

从构建日志分析：
- **总构建时间**: 25分钟 (14:13-14:38)
- **Unity构建时间**: 25分钟 (几乎全部时间)
- **后续处理**: 2分钟 (压缩+上传)

## 关键发现

### 1. Git同步已由Jenkins处理
```
14:13:27 Fetching changes from the remote Git repository
14:13:34 Checking out Revision f194335abbaaa3ee62fcaecefb84628cf415e47a
```
**结论**: 不需要在构建脚本中重复Git操作

### 2. 脚本可能使用的是旧版本
日志显示: `[WARN] 非Git仓库，跳过代码同步`
**说明**: Jenkins Job配置中可能还在使用原始的批处理脚本

## 立即优化方案

### 步骤1: 更新Jenkins Job配置

将Jenkins Job中的构建脚本替换为 `jenkins_optimized_build.bat`

**关键优化点**:
- ✅ 移除重复的Git同步操作
- ✅ 基于Jenkins的GIT_COMMIT环境变量做增量构建
- ✅ 优化Unity构建参数
- ✅ 添加详细的时间统计
- ✅ 智能缓存检测

### 步骤2: Jenkins环境变量优化

在Jenkins Job配置中添加这些环境变量：
```
UNITY_MIXED_CALLSTACK=1
UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1
```

### 步骤3: Jenkins构建触发优化

**当前问题**: 每次构建都是完整构建
**解决方案**: 
1. 启用Jenkins的增量构建检测
2. 使用SCM轮询而不是强制清理工作空间

在Jenkins Job配置中：
- ✅ 取消勾选 "Delete workspace before build starts"
- ✅ 启用 "Use SCM polling" 
- ✅ 配置合理的polling schedule

## 预期性能提升

| 优化项目 | 当前耗时 | 优化后预期 | 节省时间 |
|---------|---------|-----------|---------|
| Git同步重复操作 | 1-2分钟 | 0分钟 | 1-2分钟 |
| Unity增量构建 | 25分钟 | 10-15分钟 | 10-15分钟 |
| 缓存清理优化 | - | - | 2-3分钟 |
| **总计** | **25分钟** | **10-15分钟** | **13-20分钟** |

## 具体实施步骤

### 1. 备份当前配置
在Jenkins中复制当前Job作为备份

### 2. 更新构建脚本
将 `jenkins_optimized_build.bat` 的内容复制到Jenkins Job的构建步骤中

### 3. 配置环境变量
在Jenkins Job的"构建环境"部分添加：
```
UNITY_MIXED_CALLSTACK=1
UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
```

### 4. 调整SCM配置
- 源码管理 → Git → Additional Behaviours
- 添加 "Clean before checkout" (但不要删除整个workspace)
- 移除强制workspace清理

### 5. 测试验证

运行优化后的构建，观察日志中的关键指标：
```
[DEBUG] 使用Jenkins Git信息: f194335abbaaa...
[DEBUG] 当前构建Hash: f194335abbaaa..._1.0.0
[DEBUG] 上次构建Hash: (首次构建时为空)
[TIMING] Unity构建开始时间: 14:13:34
[TIMING] Unity构建结束时间: 14:23:45  ← 目标: 减少到10分钟内
```

## 高级优化建议

### 1. Unity项目级优化
在Unity项目中添加构建脚本优化：
```csharp
// 在BuilldPlayerTools.BuildPlayer方法中添加
EditorUserBuildSettings.development = false;
PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.IL2CPP);
```

### 2. Jenkins节点优化
- 确保构建节点有足够的CPU和内存
- 使用SSD存储
- 配置专用的Unity构建agent

### 3. 并行构建考虑
如果有多个分支需要构建，考虑：
- 使用Jenkins多分支Pipeline
- 配置多个构建节点
- 实施构建队列优化

## 监控和测量

实施优化后，重点监控：
1. **总构建时间**: 目标从25分钟减少到10-15分钟
2. **增量构建命中率**: 目标达到60%以上
3. **Unity构建时间**: 目标减少40-50%
4. **缓存效率**: 观察缓存命中情况

## 问题排查

如果优化后仍有问题：

1. **检查环境变量是否生效**:
   ```batch
   echo %GIT_COMMIT%
   echo %UNITY_MIXED_CALLSTACK%
   ```

2. **检查增量构建逻辑**:
   ```batch
   type "%CACHE_DIR%\last_build_hash.txt"
   ```

3. **分析Unity日志**:
   ```batch
   type "%WORKSPACE%\unity_build.log" | findstr "compilation time\|build time"
   ```

## 总结

这次优化主要解决了：
- **重复Git操作**问题
- **缺乏增量构建**问题  
- **Unity构建参数**不够优化的问题

预期能将构建时间从**25分钟减少到10-15分钟**，节省**40-60%**的构建时间。