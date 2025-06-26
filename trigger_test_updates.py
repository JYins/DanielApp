#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import time
from datetime import datetime

def run_command(cmd, timeout=10):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception as e:
        print(f"❌ 命令执行错误: {e}")
        return None

def check_app_status():
    """检查应用状态"""
    print("📱 检查应用状态...")
    
    # 检查DanielApp进程
    app_processes = run_command("ps aux | grep -i danielapp | grep -v grep")
    if app_processes:
        print("✅ DanielApp 正在运行")
        print(f"   进程信息: {app_processes}")
    else:
        print("❌ DanielApp 未运行")
    
    # 检查Widget Extension进程
    widget_processes = run_command("ps aux | grep -i widget | grep -v grep")
    if widget_processes:
        print("✅ Widget Extension 相关进程:")
        print(f"   {widget_processes}")
    else:
        print("❌ 未找到Widget Extension进程")

def enable_test_mode():
    """启用测试模式"""
    print("\n🧪 启用测试模式...")
    
    # 设置测试模式标志
    cmd = "defaults write group.com.daniel.DanielApp test_mode_enabled -bool true"
    result = run_command(cmd)
    
    # 设置测试更新间隔
    cmd2 = "defaults write group.com.daniel.DanielApp test_update_interval -int 60"
    result2 = run_command(cmd2)
    
    # 触发立即更新
    cmd3 = "defaults write group.com.daniel.DanielApp force_update_now -bool true"
    result3 = run_command(cmd3)
    
    print("✅ 测试模式已启用")
    print("   - 测试模式: 开启")
    print("   - 更新间隔: 60秒")
    print("   - 立即更新: 已触发")

def monitor_test_updates():
    """监控测试更新"""
    print("\n🔍 开始监控测试更新...")
    print("监控时间: 5分钟")
    print("检查间隔: 15秒")
    print("=" * 50)
    
    initial_time = datetime.now()
    last_reference = None
    update_count = 0
    
    for i in range(20):  # 监控20次，每次15秒
        current_time = datetime.now()
        elapsed = (current_time - initial_time).total_seconds()
        
        print(f"\n--- 第{i+1}次检查 (已运行{elapsed:.0f}秒) ---")
        
        # 获取当前Widget状态
        ref_cmd = "defaults read group.com.daniel.DanielApp verse_reference 2>/dev/null || echo '未设置'"
        current_reference = run_command(ref_cmd) or "未设置"
        
        # 获取测试模式状态
        test_mode_cmd = "defaults read group.com.daniel.DanielApp test_mode_enabled 2>/dev/null || echo '0'"
        test_mode = run_command(test_mode_cmd) or "0"
        
        print(f"   ⏰ 当前时间: {current_time.strftime('%H:%M:%S')}")
        print(f"   📖 经文引用: {current_reference}")
        print(f"   🧪 测试模式: {'开启' if test_mode == '1' else '关闭'}")
        
        # 检查是否有更新
        if last_reference and current_reference != last_reference:
            update_count += 1
            print(f"🎉 检测到更新! (第{update_count}次)")
            print(f"   📖 旧引用: {last_reference}")
            print(f"   📖 新引用: {current_reference}")
        elif last_reference:
            print("⏸️  无变化")
        
        last_reference = current_reference
        
        # 每隔1分钟手动触发一次更新
        if (i + 1) % 4 == 0:
            print("🔄 手动触发更新...")
            trigger_cmd = "defaults write group.com.daniel.DanielApp force_update_now -bool true"
            run_command(trigger_cmd)
            time.sleep(2)  # 等待更新处理
        
        time.sleep(15)
    
    print(f"\n📊 监控总结:")
    print(f"   ⏰ 总监控时间: 5分钟")
    print(f"   🔄 总检查次数: 20")
    print(f"   📈 检测到更新: {update_count}次")
    
    return update_count > 0

def main():
    print("🧪 Widget测试更新触发器")
    print("=" * 40)
    
    # 检查应用状态
    check_app_status()
    
    # 启用测试模式
    enable_test_mode()
    
    # 等待几秒让设置生效
    print("\n⏳ 等待设置生效...")
    time.sleep(5)
    
    # 开始监控
    has_updates = monitor_test_updates()
    
    if has_updates:
        print("\n🎉 测试成功! Widget更新机制正常工作")
    else:
        print("\n⚠️  测试期间未检测到Widget更新")
        print("可能原因:")
        print("1. 应用未在后台运行")
        print("2. 测试模式未正确启用")
        print("3. Widget更新机制需要调试")
    
    # 清理测试设置
    print("\n🧹 清理测试设置...")
    run_command("defaults delete group.com.daniel.DanielApp test_mode_enabled 2>/dev/null")
    run_command("defaults delete group.com.daniel.DanielApp test_update_interval 2>/dev/null")
    run_command("defaults delete group.com.daniel.DanielApp force_update_now 2>/dev/null")
    print("✅ 清理完成")

if __name__ == "__main__":
    main()
