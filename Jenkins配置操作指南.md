# Jenkins作业配置操作指南

## 步骤1：添加环境变量

### 方法A：在作业级别添加环境变量（推荐）

1. **进入作业配置**
   - 登录Jenkins
   - 找到您的构建作业（如：`bpc_xr_innovation13340`）
   - 点击作业名称进入作业页面
   - 点击左侧菜单的 **"配置"** 或 **"Configure"**

2. **找到构建环境设置**
   - 在配置页面中，向下滚动找到 **"构建环境"** 或 **"Build Environment"** 部分
   - 勾选 **"Set environment variables"** 或 **"设置环境变量"**
   - 如果没有这个选项，查找 **"Inject environment variables"** 插件

3. **添加环境变量**
   在文本框中输入：
   ```
   UNITY_MIXED_CALLSTACK=1
   UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
   UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1
   ```

   **格式说明**：
   - 每行一个变量
   - 格式：`变量名=值`
   - 不要有多余的空格

### 方法B：使用EnvInject插件（如果已安装）

1. **找到EnvInject部分**
   - 在"构建环境"部分，勾选 **"Inject environment variables to the build process"**

2. **添加变量**
   - 在 **"Properties Content"** 文本框中输入：
   ```
   UNITY_MIXED_CALLSTACK=1
   UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
   UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1
   ```

### 方法C：在构建脚本中设置（备选方案）

如果以上方法不可用，可以在批处理脚本开头添加：
```batch
@echo off
:: 设置Unity优化环境变量
set UNITY_MIXED_CALLSTACK=1
set UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
set UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1

:: 验证环境变量设置
echo [DEBUG] UNITY_MIXED_CALLSTACK=%UNITY_MIXED_CALLSTACK%
echo [DEBUG] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=%UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES%

:: 其余构建脚本...
```

## 步骤2：调整SCM（Git）配置

### 2.1 找到源码管理设置

1. **在作业配置页面中找到"源码管理"部分**
   - 通常在页面上方，显示 **"Source Code Management"** 或 **"源码管理"**
   - 应该已经选择了 **"Git"** 选项

### 2.2 检查当前Git配置

查看当前配置，通常包含：
- **Repository URL**: `https://git.corpautohome.com/bpc_xr_innovation/pj_xr_holographic.git`
- **Credentials**: 您的Git凭据
- **Branches to build**: 如 `*/develop` 或 `*/release/6.3.0`

### 2.3 移除强制workspace清理

**找到以下设置并取消勾选**：

1. **"Clean before checkout"**
   - 如果勾选了，请取消勾选
   - 位置：Git配置下方的"Additional Behaviours"部分

2. **"Delete workspace before build starts"**
   - 在"构建环境"部分查找
   - 如果勾选了，请**取消勾选**

3. **"Wipe out repository & force clone"**
   - 在Git的"Additional Behaviours"中查找
   - 如果添加了这个行为，请**删除**

### 2.4 推荐的Git配置

**保留的设置**：
- ✅ Repository URL
- ✅ Credentials  
- ✅ Branches to build

**移除的设置**：
- ❌ Clean before checkout
- ❌ Delete workspace before build starts
- ❌ Wipe out repository & force clone

**可选添加**：
- ✅ "Sparse Checkout paths"（如果只需要特定目录）
- ✅ "Shallow clone"（减少clone时间）

## 步骤3：验证配置

### 3.1 保存配置
- 点击页面底部的 **"保存"** 或 **"Save"** 按钮

### 3.2 测试构建
1. **运行一次测试构建**
   - 点击 **"立即构建"** 或 **"Build Now"**

2. **检查构建日志**
   查看日志中是否出现：
   ```
   [DEBUG] UNITY_MIXED_CALLSTACK=1
   [DEBUG] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
   [INFO] Jenkins已完成代码同步，开始构建优化检查...
   ```

### 3.3 观察构建时间变化
- **第一次构建**：可能仍需要较长时间（15-25分钟）
- **第二次构建**：如果代码没有变化，应该显著缩短

## 故障排除

### 问题1：找不到环境变量设置选项

**解决方案**：
1. 检查是否安装了"Environment Injector Plugin"
2. 如果没有，可以在构建脚本开头手动设置环境变量

### 问题2：Git仍然完全清理workspace

**检查位置**：
1. **General** → "Delete workspace before build starts"
2. **Source Code Management** → "Additional Behaviours"  
3. **Build Environment** → 任何cleanup相关选项

### 问题3：环境变量不生效

**验证方法**：
在构建脚本中添加调试输出：
```batch
echo [DEBUG] 当前环境变量:
echo [DEBUG] UNITY_MIXED_CALLSTACK=%UNITY_MIXED_CALLSTACK%
echo [DEBUG] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=%UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES%
echo [DEBUG] GIT_COMMIT=%GIT_COMMIT%
echo [DEBUG] WORKSPACE=%WORKSPACE%
```

## 配置检查清单

完成配置后，请确认：

### ✅ 环境变量部分
- [ ] UNITY_MIXED_CALLSTACK=1
- [ ] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
- [ ] UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1

### ✅ Git配置部分
- [ ] Repository URL正确
- [ ] Credentials有效
- [ ] 分支配置正确
- [ ] **未勾选** "Delete workspace before build starts"
- [ ] **未添加** "Clean before checkout"行为
- [ ] **未添加** "Wipe out repository"行为

### ✅ 构建脚本部分
- [ ] 使用了优化后的批处理脚本
- [ ] 脚本中包含环境变量验证输出

## 预期结果

配置完成后的构建日志应该包含：
```
[DEBUG] UNITY_MIXED_CALLSTACK=1
[DEBUG] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
[INFO] Jenkins已完成代码同步，开始构建优化检查...
[DEBUG] 使用Jenkins Git信息: f194335abbaaa...
[DEBUG] 当前构建Hash: f194335abbaaa..._1.0.0
[TIMING] Unity构建开始时间: XX:XX:XX
```

如果看到这些信息，说明配置成功！