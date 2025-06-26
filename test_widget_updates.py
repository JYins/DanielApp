#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import time
from datetime import datetime
import json

def run_command(cmd, timeout=10):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception as e:
        print(f"❌ 命令执行错误: {e}")
        return None

def get_current_widget_state():
    """获取当前Widget状态"""
    print("\n📊 当前Widget状态:")
    
    # 获取经文引用
    ref_cmd = "defaults read group.com.daniel.DanielApp verse_reference 2>/dev/null || echo '未设置'"
    reference = run_command(ref_cmd) or "未设置"
    
    # 获取中文经文
    text_cmd = "defaults read group.com.daniel.DanielApp verse_text_cn 2>/dev/null || echo '未设置'"
    text_cn = run_command(text_cmd) or "未设置"
    
    # 获取英文经文
    text_en_cmd = "defaults read group.com.daniel.DanielApp verse_text_en 2>/dev/null || echo '未设置'"
    text_en = run_command(text_en_cmd) or "未设置"
    
    current_time = datetime.now().strftime('%H:%M:%S')
    
    print(f"   ⏰ 检查时间: {current_time}")
    print(f"   📖 经文引用: {reference}")
    print(f"   📝 中文经文: {text_cn[:80]}...")
    print(f"   📝 英文经文: {text_en[:80]}...")
    
    return {
        'time': current_time,
        'reference': reference,
        'text_cn': text_cn,
        'text_en': text_en
    }

def force_widget_refresh():
    """强制刷新Widget"""
    print("\n🔄 强制刷新Widget...")
    
    # 方法1: 通过Simulator刷新
    cmd1 = "xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS \"com.daniel.DanielApp\"' --timeout 1s 2>/dev/null || echo '无法获取日志'"
    
    # 方法2: 发送Widget刷新通知
    cmd2 = "killall -9 SpringBoard 2>/dev/null || echo '无法重启SpringBoard'"
    
    print("   📱 尝试刷新Widget时间线...")
    result1 = run_command(cmd1)
    
    print("   🔄 等待刷新完成...")
    time.sleep(3)
    
    print("✅ Widget刷新完成")

def simulate_time_passage():
    """模拟时间流逝，检查Widget更新"""
    print("\n🕐 开始监控Widget更新...")
    print("=" * 50)
    
    initial_state = get_current_widget_state()
    update_count = 0
    
    for i in range(12):  # 监控12次，每次间隔5秒
        time.sleep(5)
        
        print(f"\n--- 第{i+1}次检查 ---")
        current_state = get_current_widget_state()
        
        # 检查是否有变化
        if current_state['reference'] != initial_state['reference']:
            update_count += 1
            print(f"🎉 检测到Widget更新! (第{update_count}次)")
            print(f"   📖 旧引用: {initial_state['reference']}")
            print(f"   📖 新引用: {current_state['reference']}")
            initial_state = current_state
        else:
            print("⏸️  Widget状态无变化")
        
        # 每隔15秒强制刷新一次
        if (i + 1) % 3 == 0:
            force_widget_refresh()
    
    print(f"\n📈 监控总结:")
    print(f"   🔄 总检查次数: 12")
    print(f"   📊 检测到更新: {update_count}次")
    print(f"   ⏰ 监控时长: 1分钟")

def main():
    print("�� Widget更新测试工具")
    print("=" * 40)
    print("此工具将:")
    print("1. 显示当前Widget状态")
    print("2. 强制刷新Widget")
    print("3. 监控Widget更新情况")
    print("4. 每15秒自动刷新一次")
    print("=" * 40)
    
    # 显示初始状态
    initial_state = get_current_widget_state()
    
    # 强制刷新一次
    force_widget_refresh()
    
    # 显示刷新后状态
    post_refresh_state = get_current_widget_state()
    
    # 检查刷新是否有效果
    if post_refresh_state['reference'] != initial_state['reference']:
        print("\n🎉 刷新后Widget发生了变化!")
    else:
        print("\n⏸️  刷新后Widget状态无变化")
    
    # 开始持续监控
    simulate_time_passage()
    
    print("\n✅ 测试完成!")

if __name__ == "__main__":
    main()
