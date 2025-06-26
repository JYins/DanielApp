#!/usr/bin/env python3
import subprocess
import time
import json
from datetime import datetime

def run_command(cmd):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
        return result.stdout.strip()
    except:
        return ""

def get_widget_state():
    """获取Widget当前状态"""
    cmd = "defaults read com.daniel.DanielApp"
    result = run_command(cmd)
    
    state = {
        'timestamp': datetime.now().strftime('%H:%M:%S'),
        'verse_reference': 'N/A',
        'verse_text_chinese': 'N/A',
        'last_update': 'N/A'
    }
    
    if result:
        try:
            # 简单解析输出
            lines = result.split('\n')
            for line in lines:
                if 'verse_reference' in line:
                    state['verse_reference'] = line.split('=')[1].strip().strip('"').strip(';')
                elif 'verse_text_chinese' in line:
                    state['verse_text_chinese'] = line.split('=')[1].strip().strip('"').strip(';')[:50] + "..."
                elif 'last_update_time' in line:
                    state['last_update'] = line.split('=')[1].strip().strip('"').strip(';')
        except:
            pass
    
    return state

def check_app_status():
    """检查应用是否在运行"""
    cmd = "ps aux | grep -i 'danielapp' | grep -v grep | wc -l"
    count = run_command(cmd)
    return int(count) > 0

def main():
    print("=== DanielApp Widget 监控器 ===")
    print("监控开始... (按 Ctrl+C 停止)")
    print("-" * 50)
    
    last_state = None
    update_count = 0
    
    try:
        while True:
            # 检查应用状态
            app_running = check_app_status()
            
            # 获取当前状态
            current_state = get_widget_state()
            
            # 检查是否有更新
            if last_state and current_state != last_state:
                update_count += 1
                print(f"🔄 更新检测到! (第 {update_count} 次)")
            
            # 显示状态
            print(f"[{current_state['timestamp']}] 应用运行: {'✅' if app_running else '❌'}")
            print(f"  经文引用: {current_state['verse_reference']}")
            print(f"  经文内容: {current_state['verse_text_chinese']}")
            print(f"  最后更新: {current_state['last_update']}")
            print(f"  总更新次数: {update_count}")
            print("-" * 50)
            
            last_state = current_state.copy()
            time.sleep(10)  # 每10秒检查一次
            
    except KeyboardInterrupt:
        print(f"\n监控结束. 总共检测到 {update_count} 次更新")

if __name__ == "__main__":
    main() 