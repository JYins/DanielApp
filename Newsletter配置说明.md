# Newsletter配置说明

## 问题排查

Newsletter卡片没有正确显示文字信息，问题可能出现在以下几个地方：

### 1. 配置文件格式
确保Firebase Storage中newsletters文件夹下每个子文件夹都包含`config.json`文件，格式如下：

```json
{
    "captions": {
        "chinese": "中文Newsletter内容",
        "english": "English Newsletter content", 
        "korean": "한국어 Newsletter 내용"
    },
    "publishDate": "2025-01-15",
    "isPublished": true
}
```

### 2. Firebase Storage结构
```
newsletters/
├── 2025-01/
│   ├── config.json
│   ├── image1.jpg
│   └── image2.jpg
├── 2025-02/
│   ├── config.json
│   └── newsletter.png
```

### 3. 调试信息
应用启动后，在Xcode Console中查看以下调试信息：

- `✅ 找到Newsletter文件夹: [...]` - 确认文件夹被找到
- `🔍 调试：xxx文件夹包含的文件:` - 确认文件夹内容
- `✅ 成功解析Newsletter配置，文字内容：` - 确认配置文件解析成功
- `❌ 解析Newsletter配置失败:` - 如果出现此错误，检查JSON格式

### 4. 测试功能
应用现在会自动添加一个测试Newsletter（ID: test-2025-01），用于验证卡片文字显示功能是否正常。

### 5. 与话语卡片的差异
Newsletter和话语卡片使用相同的配置文件格式，但Newsletter有额外字段：
- `publishDate`: 发布日期
- `isPublished`: 是否发布

### 6. 常见问题
1. **配置文件名称错误**: 必须是`config.json`（全小写）
2. **JSON格式错误**: 确保引号、逗号、括号正确
3. **编码问题**: 确保文件使用UTF-8编码
4. **权限问题**: 确保Firebase Storage权限正确设置

### 7. 解决方案
如果Newsletter仍然不显示文字：
1. 检查Xcode Console的详细日志
2. 确认Firebase Storage中的文件结构和内容
3. 验证JSON配置文件格式
4. 重新上传配置文件（删除旧的，上传新的） 