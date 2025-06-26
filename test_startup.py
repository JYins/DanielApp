#!/usr/bin/env python3
import subprocess
import time
import os

def run_command(cmd, timeout=10):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "命令超时"
    except Exception as e:
        return -1, "", str(e)

def check_settings():
    """检查当前设置"""
    print("📋 检查当前设置:")
    code, output, error = run_command("defaults read com.daniel.DanielApp")
    if code == 0:
        print(output)
    else:
        print(f"❌ 读取设置失败: {error}")
    print("-" * 50)

def setup_test_mode():
    """设置测试模式"""
    print("⚙️ 设置测试模式...")
    
    # 设置测试模式
    run_command("defaults write com.daniel.DanielApp test_mode_enabled 1")
    run_command("defaults write com.daniel.DanielApp force_update_now 1")
    run_command("defaults write com.daniel.DanielApp test_update_interval 60")
    
    print("✅ 测试模式设置完成")

def check_app_processes():
    """检查应用进程"""
    print("🔍 检查应用进程:")
    code, output, error = run_command("ps aux | grep -i danielapp | grep -v grep")
    if output:
        print("运行中的DanielApp进程:")
        print(output)
    else:
        print("❌ 没有发现DanielApp进程")
    print("-" * 50)

def simulate_app_launch():
    """模拟应用启动场景"""
    print("🚀 模拟应用启动场景...")
    
    # 清除现有设置
    print("清除现有设置...")
    run_command("defaults delete com.daniel.DanielApp test_mode_enabled 2>/dev/null")
    run_command("defaults delete com.daniel.DanielApp force_update_now 2>/dev/null")
    
    # 设置新的测试模式
    setup_test_mode()
    
    # 检查设置结果
    check_settings()

def monitor_logs():
    """监控应用日志"""
    print("📝 监控应用日志 (10秒)...")
    code, output, error = run_command("log stream --predicate 'process == \"DanielApp\"' --timeout 10")
    if output:
        print("应用日志:")
        print(output[-1000:])  # 显示最后1000个字符
    else:
        print("❌ 没有获取到应用日志")
    print("-" * 50)

def main():
    print("=== DanielApp 启动测试 ===")
    print("测试应用启动时的测试模式初始化")
    print("=" * 50)
    
    # 1. 检查当前进程状态
    check_app_processes()
    
    # 2. 模拟应用启动
    simulate_app_launch()
    
    # 3. 等待一段时间让应用处理
    print("⏳ 等待5秒让应用处理设置...")
    time.sleep(5)
    
    # 4. 再次检查设置
    print("🔄 检查设置更新后的状态:")
    check_settings()
    
    # 5. 检查进程状态
    check_app_processes()
    
    # 6. 监控日志
    monitor_logs()
    
    print("✅ 测试完成!")

if __name__ == "__main__":
    main() 