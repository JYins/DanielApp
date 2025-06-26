#!/bin/bash
echo "📊 检查更新前后的数据变化"
echo "时间: $(date)"
echo "----------------------------------------"
echo "🔍 UserDefaults数据:"
defaults read group.com.daniel.DanielApp 2>/dev/null | grep -E "(verse|reference|time|update)" | head -5
echo ""
echo "🔍 Widget配置:"
echo "Language: $(defaults read group.com.daniel.DanielApp widget_language 2>/dev/null || echo '未设置')"
echo "Update Mode: $(defaults read group.com.daniel.DanielApp widget_update_mode 2>/dev/null || echo '未设置')"
echo "Current Reference: $(defaults read group.com.daniel.DanielApp currentVerseReference 2>/dev/null || echo '未设置')"
echo "=========================================="
