#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import time
import json
from datetime import datetime
import threading
import sys

class WidgetUpdateMonitor:
    def __init__(self):
        self.monitoring = False
        self.last_reference = None
        self.last_update_time = None
        self.update_count = 0
        
    def run_command(self, cmd):
        """执行命令并返回结果"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
            return result.stdout.strip() if result.returncode == 0 else None
        except subprocess.TimeoutExpired:
            return None
        except Exception as e:
            print(f"❌ 命令执行错误: {e}")
            return None
    
    def get_current_widget_data(self):
        """获取当前Widget数据"""
        # 尝试从App Group获取数据
        cmd = "defaults read group.com.daniel.DanielApp verse_reference 2>/dev/null || echo '未设置'"
        reference = self.run_command(cmd)
        
        cmd = "defaults read group.com.daniel.DanielApp verse_text_cn 2>/dev/null || echo '未设置'"
        text_cn = self.run_command(cmd)
        
        return {
            'reference': reference or '未设置',
            'text_cn': text_cn or '未设置',
            'timestamp': datetime.now().strftime('%H:%M:%S')
        }
    
    def check_widget_update(self):
        """检查Widget是否更新"""
        current_data = self.get_current_widget_data()
        current_reference = current_data['reference']
        current_time = current_data['timestamp']
        
        # 检查是否有变化
        has_changed = False
        if self.last_reference is None:
            # 首次检查
            self.last_reference = current_reference
            self.last_update_time = current_time
            print(f"📊 [{current_time}] 初始Widget状态:")
            print(f"   📖 引用: {current_reference}")
            print(f"   📝 中文: {current_data['text_cn'][:50]}...")
        elif self.last_reference != current_reference:
            # 检测到变化
            has_changed = True
            self.update_count += 1
            print(f"🔄 [{current_time}] Widget更新检测到! (第{self.update_count}次)")
            print(f"   📖 旧引用: {self.last_reference}")
            print(f"   📖 新引用: {current_reference}")
            print(f"   📝 新中文: {current_data['text_cn'][:50]}...")
            
            self.last_reference = current_reference
            self.last_update_time = current_time
        else:
            # 无变化
            print(f"⏰ [{current_time}] Widget状态无变化: {current_reference}")
        
        return has_changed
    
    def monitor_app_logs(self):
        """监控应用日志"""
        print("📱 开始监控应用日志...")
        
        # 监控Widget相关日志
        cmd = "log stream --predicate 'subsystem CONTAINS \"com.daniel.DanielApp\" OR process CONTAINS \"daniel\"' --style compact"
        
        try:
            process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            
            while self.monitoring:
                line = process.stdout.readline()
                if line:
                    line = line.strip()
                    if any(keyword in line.lower() for keyword in ['widget', 'update', 'midnight', 'test']):
                        timestamp = datetime.now().strftime('%H:%M:%S')
                        print(f"📋 [{timestamp}] 日志: {line}")
                
                time.sleep(0.1)
                
        except Exception as e:
            print(f"❌ 日志监控错误: {e}")
    
    def start_monitoring(self):
        """开始监控"""
        print("🚀 开始Widget更新监控...")
        print("=" * 60)
        
        self.monitoring = True
        
        # 启动日志监控线程
        log_thread = threading.Thread(target=self.monitor_app_logs)
        log_thread.daemon = True
        log_thread.start()
        
        # 主监控循环
        try:
            while self.monitoring:
                self.check_widget_update()
                
                # 每10秒检查一次
                time.sleep(10)
                
        except KeyboardInterrupt:
            print("\n🛑 监控已停止")
            self.monitoring = False
    
    def show_current_status(self):
        """显示当前状态"""
        print("📊 当前Widget状态:")
        current_data = self.get_current_widget_data()
        print(f"   📖 引用: {current_data['reference']}")
        print(f"   📝 中文: {current_data['text_cn'][:100]}...")
        print(f"   ⏰ 检查时间: {current_data['timestamp']}")
        print(f"   🔄 更新次数: {self.update_count}")

def main():
    monitor = WidgetUpdateMonitor()
    
    print("🧪 Widget更新监控工具")
    print("=" * 40)
    print("此工具将:")
    print("1. 每10秒检查Widget数据变化")
    print("2. 实时监控应用日志")
    print("3. 记录所有更新事件")
    print("4. 按Ctrl+C停止监控")
    print("=" * 40)
    
    # 显示初始状态
    monitor.show_current_status()
    print()
    
    # 开始监控
    monitor.start_monitoring()

if __name__ == "__main__":
    main()
