# Unity构建参数详解

## 参数分类

### 1. Windows环境变量（在批处理脚本中设置）

```batch
:: 设置Unity环境变量以优化性能
set UNITY_MIXED_CALLSTACK=1
set UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30
```

#### `UNITY_MIXED_CALLSTACK=1`
- **作用**: 启用混合调用堆栈，改善崩溃报告的质量
- **位置**: 批处理脚本中，Unity启动前设置
- **影响**: 提高调试信息质量，轻微性能开销但有助于问题诊断

#### `UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES=30`
- **作用**: 设置Shader编译任务的超时时间为30分钟
- **位置**: 批处理脚本中，Unity启动前设置
- **影响**: 防止复杂Shader编译时超时导致构建失败

### 2. Unity命令行参数（传递给Unity.exe）

```batch
"%UNITY_PATH%" ^
  -batchmode ^
  -quit ^
  -nographics ^
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
```

#### 标准Unity参数
- **`-batchmode`**: 以批处理模式运行，不显示GUI
- **`-quit`**: 构建完成后自动退出Unity
- **`-nographics`**: 不初始化图形设备，节省GPU资源
- **`-buildTarget Win64`**: 指定构建目标平台为Windows 64位

#### 缓存相关参数
- **`-cacheServerEndpoint none`**: 禁用缓存服务器连接
- **`-buildCacheVersion 1`**: 设置构建缓存版本（用于增量构建）
- **`-enableCacheServer false`**: 确保不使用外部缓存服务器

## 在Unity构建脚本中的使用

### 当前的BuilldPlayerTools.BuildPlayer方法
您的Unity构建方法不需要处理这些命令行参数，因为它们由Unity引擎自动处理：

```csharp
// BuilldPlayerTools.BuildPlayer 方法示例
public static void BuildPlayer()
{
    // 这些参数会自动从命令行传入：
    // - productName 来自 -productName=Holo
    // - version 来自 -version=%VERSION%
    // - prefixDir 来自 -prefixDir="%RESULT_DIR%"
    
    string[] args = System.Environment.GetCommandLineArgs();
    
    // 解析命令行参数
    string productName = GetCommandLineArg("-productName");
    string version = GetCommandLineArg("-version");
    string outputPath = GetCommandLineArg("-prefixDir");
    
    // 设置构建选项
    BuildPlayerOptions buildOptions = new BuildPlayerOptions();
    buildOptions.scenes = GetEnabledScenes();
    buildOptions.locationPathName = Path.Combine(outputPath, productName + ".exe");
    buildOptions.target = BuildTarget.StandaloneWindows64;
    buildOptions.options = BuildOptions.None;
    
    // 执行构建
    BuildReport report = BuildPipeline.BuildPlayer(buildOptions);
    
    if (report.summary.result != BuildResult.Succeeded)
    {
        EditorApplication.Exit(1);
    }
}

private static string GetCommandLineArg(string name)
{
    string[] args = System.Environment.GetCommandLineArgs();
    for (int i = 0; i < args.Length; i++)
    {
        if (args[i] == name && args.Length > i + 1)
        {
            return args[i + 1];
        }
        if (args[i].StartsWith(name + "="))
        {
            return args[i].Substring(name.Length + 1);
        }
    }
    return null;
}

private static string[] GetEnabledScenes()
{
    return EditorBuildSettings.scenes
        .Where(scene => scene.enabled)
        .Select(scene => scene.path)
        .ToArray();
}
```

## 可选的Unity构建脚本优化

如果您想在Unity构建脚本中进一步优化，可以添加这些设置：

```csharp
public static void BuildPlayer()
{
    // 1. 优化编辑器设置（仅在构建时）
    var originalDevelopment = EditorUserBuildSettings.development;
    var originalDeepProfile = EditorUserBuildSettings.connectProfiler;
    var originalScriptDebugging = EditorUserBuildSettings.allowDebugging;
    
    try
    {
        // 禁用开发模式以加快构建
        EditorUserBuildSettings.development = false;
        EditorUserBuildSettings.connectProfiler = false;
        EditorUserBuildSettings.allowDebugging = false;
        
        // 2. 设置脚本后端（如果需要）
        PlayerSettings.SetScriptingBackend(
            BuildTargetGroup.Standalone, 
            ScriptingImplementation.IL2CPP
        );
        
        // 3. 优化纹理设置（仅构建时）
        var textureImporters = AssetDatabase.FindAssets("t:Texture2D")
            .Select(AssetDatabase.GUIDToAssetPath)
            .Select(AssetImporter.GetAtPath)
            .OfType<TextureImporter>()
            .ToArray();
            
        // 临时降低纹理质量以加快构建
        foreach (var importer in textureImporters)
        {
            var settings = importer.GetPlatformTextureSettings("Standalone");
            if (settings.maxTextureSize > 2048)
            {
                settings.maxTextureSize = 2048;
                importer.SetPlatformTextureSettings(settings);
            }
        }
        
        // 执行实际构建
        PerformBuild();
        
    }
    finally
    {
        // 恢复原始设置
        EditorUserBuildSettings.development = originalDevelopment;
        EditorUserBuildSettings.connectProfiler = originalDeepProfile;
        EditorUserBuildSettings.allowDebugging = originalScriptDebugging;
    }
}
```

## 参数效果总结

| 参数类型 | 参数名 | 设置位置 | 主要作用 | 性能影响 |
|---------|--------|----------|----------|----------|
| 环境变量 | `UNITY_MIXED_CALLSTACK` | 批处理脚本 | 改善崩溃报告 | 微小开销 |
| 环境变量 | `UNITY_SHADER_COMPILER_TASK_TIMEOUT_MINUTES` | 批处理脚本 | 防止Shader编译超时 | 避免构建失败 |
| 命令行 | `-nographics` | Unity.exe参数 | 禁用图形界面 | 节省GPU资源 |
| 命令行 | `-buildTarget Win64` | Unity.exe参数 | 指定构建目标 | 避免平台切换 |
| 命令行 | `-cacheServerEndpoint none` | Unity.exe参数 | 禁用缓存服务器 | 避免网络延迟 |
| 命令行 | `-enableCacheServer false` | Unity.exe参数 | 确保本地构建 | 提高可靠性 |

## 建议

1. **保持当前配置**: 您的批处理脚本已经正确使用了这些参数
2. **Unity脚本无需修改**: `BuilldPlayerTools.BuildPlayer`不需要处理这些系统级参数
3. **可选优化**: 如果需要进一步优化，可以在Unity构建脚本中添加上述的编辑器设置优化