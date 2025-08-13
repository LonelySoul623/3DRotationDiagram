using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

public class BuilldPlayerTools
{
    public static void BuildPlayer()
    {
        try
        {
            Debug.Log("[BUILD] 开始Unity构建流程...");
            
            // 解析命令行参数
            string productName = GetCommandLineArg("-productName") ?? "Holo";
            string version = GetCommandLineArg("-version") ?? "1.0.0";
            string outputPath = GetCommandLineArg("-prefixDir");
            
            if (string.IsNullOrEmpty(outputPath))
            {
                Debug.LogError("[BUILD] 未指定输出路径 (-prefixDir)");
                EditorApplication.Exit(1);
                return;
            }
            
            Debug.Log($"[BUILD] 产品名称: {productName}");
            Debug.Log($"[BUILD] 版本: {version}");
            Debug.Log($"[BUILD] 输出路径: {outputPath}");
            
            // 确保输出目录存在
            if (!Directory.Exists(outputPath))
            {
                Directory.CreateDirectory(outputPath);
                Debug.Log($"[BUILD] 创建输出目录: {outputPath}");
            }
            
            // 保存当前图形API设置
            var currentAPIs = PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64);
            Debug.Log($"[BUILD] 当前图形API: {string.Join(", ", currentAPIs)}");
            
            // 确保为HDRP设置正确的图形API
            EnsureHDRPCompatibleGraphicsAPIs();
            
            // 保存当前构建设置
            var originalDevelopment = EditorUserBuildSettings.development;
            var originalDeepProfile = EditorUserBuildSettings.connectProfiler;
            var originalScriptDebugging = EditorUserBuildSettings.allowDebugging;
            
            try
            {
                // 优化构建设置
                EditorUserBuildSettings.development = false;
                EditorUserBuildSettings.connectProfiler = false;
                EditorUserBuildSettings.allowDebugging = false;
                
                // 设置产品信息
                PlayerSettings.productName = productName;
                PlayerSettings.bundleVersion = version;
                
                // 获取启用的场景
                string[] scenes = GetEnabledScenes();
                if (scenes.Length == 0)
                {
                    Debug.LogError("[BUILD] 没有找到启用的场景");
                    EditorApplication.Exit(1);
                    return;
                }
                
                Debug.Log($"[BUILD] 包含场景: {string.Join(", ", scenes)}");
                
                // 设置构建选项
                BuildPlayerOptions buildOptions = new BuildPlayerOptions
                {
                    scenes = scenes,
                    locationPathName = Path.Combine(outputPath, productName + ".exe"),
                    target = BuildTarget.StandaloneWindows64,
                    targetGroup = BuildTargetGroup.Standalone,
                    options = BuildOptions.None
                };
                
                Debug.Log($"[BUILD] 开始构建到: {buildOptions.locationPathName}");
                
                // 执行构建
                BuildReport report = BuildPipeline.BuildPlayer(buildOptions);
                
                // 检查构建结果
                if (report.summary.result == BuildResult.Succeeded)
                {
                    Debug.Log($"[BUILD] 构建成功!");
                    Debug.Log($"[BUILD] 构建大小: {report.summary.totalSize / (1024 * 1024)} MB");
                    Debug.Log($"[BUILD] 构建时间: {report.summary.totalTime}");
                    EditorApplication.Exit(0);
                }
                else
                {
                    Debug.LogError($"[BUILD] 构建失败: {report.summary.result}");
                    
                    // 输出详细错误信息
                    foreach (var step in report.steps)
                    {
                        if (step.messages.Any(m => m.type == LogType.Error))
                        {
                            Debug.LogError($"[BUILD] 构建步骤 '{step.name}' 出现错误:");
                            foreach (var message in step.messages.Where(m => m.type == LogType.Error))
                            {
                                Debug.LogError($"  - {message.content}");
                            }
                        }
                    }
                    
                    EditorApplication.Exit(1);
                }
            }
            finally
            {
                // 恢复原始设置
                EditorUserBuildSettings.development = originalDevelopment;
                EditorUserBuildSettings.connectProfiler = originalDeepProfile;
                EditorUserBuildSettings.allowDebugging = originalScriptDebugging;
            }
        }
        catch (System.Exception e)
        {
            Debug.LogError($"[BUILD] 构建过程中发生异常: {e.Message}");
            Debug.LogError($"[BUILD] 堆栈跟踪: {e.StackTrace}");
            EditorApplication.Exit(1);
        }
    }
    
    private static void EnsureHDRPCompatibleGraphicsAPIs()
    {
        // 检查是否使用HDRP
        var currentRP = GraphicsSettings.currentRenderPipeline;
        if (currentRP != null && currentRP.GetType().Name.Contains("HDRenderPipeline"))
        {
            Debug.Log("[BUILD] 检测到HDRP，确保图形API兼容性...");
            
            // 获取当前图形API
            var currentAPIs = PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64);
            
            // 检查是否包含HDRP兼容的API
            bool hasCompatibleAPI = currentAPIs.Any(api => 
                api == GraphicsDeviceType.Direct3D11 || 
                api == GraphicsDeviceType.Direct3D12 || 
                api == GraphicsDeviceType.Vulkan);
            
            if (!hasCompatibleAPI)
            {
                Debug.Log("[BUILD] 设置HDRP兼容的图形API...");
                
                // 设置DirectX 11作为主要API，DirectX 12作为备选
                var newAPIs = new GraphicsDeviceType[] 
                { 
                    GraphicsDeviceType.Direct3D11,
                    GraphicsDeviceType.Direct3D12
                };
                
                PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64, newAPIs);
                Debug.Log("[BUILD] 已设置图形API为: Direct3D11, Direct3D12");
            }
            else
            {
                Debug.Log("[BUILD] 当前图形API已兼容HDRP");
            }
        }
        else
        {
            Debug.Log("[BUILD] 未检测到HDRP，保持当前图形API设置");
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
}