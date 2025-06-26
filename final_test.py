#!/usr/bin/env python3
import subprocess
import time
import json
from datetime import datetime

def run_command(cmd, timeout=10):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return -1, "", str(e)

def get_current_settings():
    """获取当前设置"""
    code, output, error = run_command("defaults read com.daniel.DanielApp")
    settings = {}
    if code == 0 and output:
        try:
            lines = output.split('\n')
            for line in lines:
                if '=' in line:
                    key = line.split('=')[0].strip().strip('"')
                    value = line.split('=')[1].strip().strip('"').strip(';')
                    settings[key] = value
        except:
            pass
    return settings

def setup_test_environment():
    """设置测试环境"""
    print("🔧 设置测试环境...")
    
    # 设置测试模式
    run_command("defaults write com.daniel.DanielApp test_mode_enabled 1")
    run_command("defaults write com.daniel.DanielApp test_update_interval 30")  # 30秒间隔
    run_command("defaults write com.daniel.DanielApp force_update_now 1")
    
    print("✅ 测试环境设置完成")

def check_app_status():
    """检查应用状态"""
    code, output, error = run_command("ps aux | grep -E 'DanielApp|daniel.*wedget' | grep -v grep")
    processes = []
    if output:
        for line in output.split('\n'):
            if line.strip():
                processes.append(line.strip())
    return processes

def force_widget_refresh():
    """强制刷新Widget"""
    print("🔄 强制刷新Widget...")
    
    # 尝试通过命令行刷新Widget
    code, output, error = run_command("xcrun simctl spawn booted com.apple.springboard refresh com.daniel.DanielApp.daniel-wedget")
    
    if code == 0:
        print("✅ Widget刷新命令执行成功")
    else:
        print(f"⚠️ Widget刷新命令失败: {error}")

def monitor_updates(duration_minutes=3):
    """监控更新"""
    print(f"📊 开始监控更新 ({duration_minutes} 分钟)...")
    
    start_time = time.time()
    end_time = start_time + (duration_minutes * 60)
    
    last_settings = get_current_settings()
    update_count = 0
    check_count = 0
    
    print(f"初始状态:")
    print(f"  经文引用: {last_settings.get('verse_reference', 'N/A')}")
    print(f"  最后更新: {last_settings.get('last_update_time', 'N/A')}")
    print("-" * 50)
    
    while time.time() < end_time:
        check_count += 1
        current_time = datetime.now().strftime('%H:%M:%S')
        
        # 获取当前设置
        current_settings = get_current_settings()
        
        # 检查是否有更新
        has_update = False
        changed_keys = []
        
        for key in ['verse_reference', 'verse_text_chinese', 'last_update_time']:
            if key in current_settings and key in last_settings:
                if current_settings[key] != last_settings[key]:
                    has_update = True
                    changed_keys.append(key)
        
        if has_update:
            update_count += 1
            print(f"🎉 [{current_time}] 检测到更新! (第 {update_count} 次)")
            print(f"  变更字段: {', '.join(changed_keys)}")
            print(f"  新经文引用: {current_settings.get('verse_reference', 'N/A')}")
            print(f"  新更新时间: {current_settings.get('last_update_time', 'N/A')}")
        else:
            print(f"⏰ [{current_time}] 检查 #{check_count} - 无更新")
        
        last_settings = current_settings.copy()
        time.sleep(15)  # 每15秒检查一次
    
    print(f"\n📈 监控结果:")
    print(f"  总检查次数: {check_count}")
    print(f"  检测到更新: {update_count} 次")
    print(f"  更新频率: {update_count / (duration_minutes * 60) * 60:.2f} 次/分钟")

def main():
    print("=" * 60)
    print("🧪 DanielApp Widget 自动更新测试")
    print("=" * 60)
    
    # 1. 检查应用状态
    print("1️⃣ 检查应用状态:")
    processes = check_app_status()
    if processes:
        print("✅ 应用正在运行:")
        for process in processes:
            print(f"  • {process}")
    else:
        print("❌ 应用未运行")
        return
    print()
    
    # 2. 设置测试环境
    print("2️⃣ 设置测试环境:")
    setup_test_environment()
    
    # 显示当前设置
    settings = get_current_settings()
    print("当前设置:")
    for key, value in settings.items():
        print(f"  {key}: {value}")
    print()
    
    # 3. 强制刷新Widget
    print("3️⃣ 强制刷新Widget:")
    force_widget_refresh()
    print()
    
    # 4. 等待初始化
    print("4️⃣ 等待初始化 (10秒)...")
    time.sleep(10)
    print()
    
    # 5. 开始监控
    print("5️⃣ 开始监控更新:")
    try:
        monitor_updates(3)  # 监控3分钟
    except KeyboardInterrupt:
        print("\n⏹️ 监控被用户中断")
    
    print("\n✅ 测试完成!")

if __name__ == "__main__":
    main() 