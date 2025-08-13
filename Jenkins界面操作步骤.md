# Jenkins界面具体操作步骤

## 🎯 快速操作路径

### 操作1：添加环境变量
```
Jenkins首页 → 点击作业名称 → 左侧"配置" → 向下滚动找"构建环境" → 勾选环境变量选项 → 输入变量 → 保存
```

### 操作2：调整Git配置  
```
Jenkins首页 → 点击作业名称 → 左侧"配置" → 向上找"源码管理" → 检查Git设置 → 移除清理选项 → 保存
```

---

## 详细界面操作

### 步骤1️⃣：进入作业配置

1. **登录Jenkins** → 打开Jenkins主页
2. **找到您的作业** → 在作业列表中找到 `bpc_xr_innovation13340`
3. **点击作业名称** → 进入作业详情页面
4. **点击"配置"** → 在左侧菜单点击"配置"或"Configure"

### 步骤2️⃣：添加环境变量

#### 情况A：有"构建环境"部分

1. **滚动页面** → 向下滚动找到 **"构建环境"** 或 **"Build Environment"**
2. **查找选项** → 寻找以下选项之一：
   - ☑️ "Set environment variables" 
   - ☑️ "Inject environment variables to the build process"
   - ☑️ "设置环境变量"

3. **勾选选项** → 勾选上述任一选项
4. **输入变量** → 在出现的文本框中输入：
   ```
   UNITY_MIXED_CALLSTACK=1
   UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
   UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1
   ```

#### 情况B：没有环境变量选项

如果找不到环境变量设置，跳到步骤4，在构建脚本中直接设置。

### 步骤3️⃣：调整Git配置

1. **找到源码管理** → 向上滚动找到 **"源码管理"** 或 **"Source Code Management"**

2. **检查Git设置** → 确认已选择"Git"，查看当前配置：
   ```
   Repository URL: https://git.corpautohome.com/bpc_xr_innovation/pj_xr_holographic.git
   Credentials: (您的Git凭据)
   Branches to build: */develop 或 */release/6.3.0
   ```

3. **检查Additional Behaviours** → 在Git配置下方查找"Additional Behaviours"部分

4. **移除清理行为** → 如果看到以下选项，请删除或取消：
   - ❌ "Clean before checkout"
   - ❌ "Wipe out repository & force clone"
   - ❌ "Delete workspace before build starts"

5. **删除方法** → 点击不需要的行为右侧的"❌"或"Delete"按钮

### 步骤4️⃣：更新构建脚本

1. **找到构建步骤** → 继续向下滚动找到 **"构建"** 或 **"Build"** 部分

2. **找到批处理命令** → 应该显示"Execute Windows batch command"

3. **更新脚本** → 将现有脚本替换为优化版本（如果环境变量无法在Jenkins中设置，则在脚本开头添加）：

```batch
@echo off
:: === Unity构建优化脚本 ===

:: 设置Unity优化环境变量（如果Jenkins中未设置）
set UNITY_MIXED_CALLSTACK=1
set UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
set UNITY_DISABLE_AUTOMATIC_SYSTEM_BOOTSTRAP=1

:: 验证环境变量
echo [DEBUG] === 环境变量检查 ===
echo [DEBUG] UNITY_MIXED_CALLSTACK=%UNITY_MIXED_CALLSTACK%
echo [DEBUG] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=%UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES%
echo [DEBUG] GIT_COMMIT=%GIT_COMMIT%
echo [DEBUG] WORKSPACE=%WORKSPACE%

:: 继续原有构建逻辑...
set BRANCH=%this_branch%
echo [CONFIRM] 构建分支: %BRANCH%

:: ... 其余构建脚本内容 ...
```

### 步骤5️⃣：保存并测试

1. **保存配置** → 点击页面底部的"保存"或"Save"按钮

2. **立即构建** → 返回作业页面，点击"立即构建"或"Build Now"

3. **查看日志** → 点击构建号码 → 点击"控制台输出"或"Console Output"

4. **验证设置** → 在日志开头查找：
   ```
   [DEBUG] === 环境变量检查 ===
   [DEBUG] UNITY_MIXED_CALLSTACK=1
   [DEBUG] UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
   [DEBUG] GIT_COMMIT=f194335abbaaa...
   ```

---

## 🔍 界面元素识别指南

### 找不到"构建环境"部分？
查找这些标题：
- "Build Environment"
- "构建环境"  
- "Environment"
- "环境设置"

### 找不到环境变量选项？
查找这些复选框：
- "Inject environment variables"
- "Set environment variables" 
- "EnvInject"
- "环境变量注入"

### Git配置界面识别
- 标题：显示"Git"图标和"Git"文字
- URL框：显示您的Git仓库地址
- 凭据下拉：显示"Credentials"
- 分支框：显示"Branches to build"

---

## ⚠️ 常见界面问题

### 问题1：页面很长，找不到相关部分
**解决**：使用浏览器的查找功能（Ctrl+F）搜索关键词：
- "Build Environment"
- "Source Code Management"  
- "构建环境"
- "源码管理"

### 问题2：选项是灰色的或不可点击
**原因**：可能没有相应权限或插件未安装
**解决**：联系Jenkins管理员或使用"方法C"在脚本中设置

### 问题3：保存后设置没有生效
**检查**：
1. 确认点击了"保存"按钮
2. 页面没有显示错误信息
3. 重新进入配置页面确认设置已保存

---

## 📋 配置完成检查清单

完成所有设置后，请确认：

### ✅ 环境变量设置
- [ ] 在Jenkins中设置了环境变量，或
- [ ] 在构建脚本开头添加了环境变量设置
- [ ] 构建日志中能看到环境变量值

### ✅ Git配置清理
- [ ] Repository URL正确
- [ ] Credentials有效  
- [ ] 分支设置正确
- [ ] 没有"Clean before checkout"
- [ ] 没有"Delete workspace before build starts"
- [ ] 没有"Wipe out repository"

### ✅ 构建脚本更新
- [ ] 使用了优化后的构建脚本
- [ ] 脚本包含调试输出
- [ ] 脚本语法正确

完成以上检查后，运行一次测试构建来验证配置是否生效！