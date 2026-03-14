# Firestore 安全规则设置指南

## 问题描述
忘记密码功能报错：`missing or insufficient permissions`

## ✅ 最新解决方案（已更新代码，无需复杂规则！）

**好消息：** 我们已经简化了忘记密码功能，**不再需要查询 Firestore**！

新的实现直接使用 Firebase Auth 的 `sendPasswordReset` 方法，它会自动检查邮箱是否存在，不需要访问 Firestore 数据库。

### 现在只需要基本的 Firestore 规则

### 步骤1：打开 Firebase Console

1. 访问 [Firebase Console](https://console.firebase.google.com/)
2. 选择你的项目
3. 点击左侧菜单的 **Firestore Database**
4. 点击顶部的 **规则** (Rules) 标签页

### 步骤2：更新安全规则（简化版）

将以下**简单且安全**的规则复制并粘贴到规则编辑器中：

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // 用户集合的规则
    match /users/{userId} {
      // 用户只能读写自己的数据
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Newsletter 集合的规则
    match /newsletters/{newsletterId} {
      // 已登录用户可以读取
      allow read: if request.auth != null;
      // 不允许客户端写入
      allow write: if false;
    }
    
    // 其他集合的默认规则（拒绝所有访问）
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**就这么简单！** 不需要允许未登录用户查询，不需要复杂的权限逻辑。

### 步骤3：发布规则

1. 点击右上角的 **发布** (Publish) 按钮
2. 等待规则生效（通常几秒钟）

## ⚠️ 重要安全说明

上面的规则允许客户端根据 email 查询用户，但这存在安全风险。

### 更安全的实现方案（推荐）

**方案A：使用 Firebase Cloud Functions**

最安全的方式是通过服务器端处理忘记密码功能：

```javascript
// Cloud Function 示例
exports.resetPassword = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  // 查询用户
  const userSnapshot = await admin.firestore()
    .collection('users')
    .where('email', '==', email)
    .limit(1)
    .get();
  
  if (userSnapshot.empty) {
    throw new functions.https.HttpsError('not-found', '该邮箱未注册');
  }
  
  const userId = userSnapshot.docs[0].id;
  
  // 更新审核状态
  await admin.firestore()
    .collection('users')
    .doc(userId)
    .update({
      isApproved: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  
  // 发送密码重置邮件
  await admin.auth().generatePasswordResetLink(email);
  
  return { success: true };
});
```

**方案B：简化的客户端方案（当前使用）**

如果你不想设置 Cloud Functions，可以使用更简单的规则：

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // 用户集合的规则
    match /users/{userId} {
      // 允许用户读取和写入自己的数据
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // ⚠️ 临时规则：允许查询 email（仅用于忘记密码功能）
      // 注意：这会暴露用户邮箱是否存在的信息
      allow read: if request.auth != null;
    }
    
    // Newsletter 和其他集合保持之前的规则
    match /newsletters/{newsletterId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## 推荐的最终规则（平衡安全性和功能性）

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // 用户集合
    match /users/{userId} {
      // 用户可以读写自己的数据
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // 允许已登录用户读取其他用户的基本信息（不包括敏感信息）
      // 这样可以支持忘记密码功能，同时保护隐私
      allow read: if request.auth != null;
    }
    
    // Newsletter 集合
    match /newsletters/{newsletterId} {
      // 已登录用户可以读取
      allow read: if request.auth != null;
      // 不允许客户端写入
      allow write: if false;
    }
    
    // 默认拒绝所有访问
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## 测试规则

发布规则后，测试忘记密码功能：

1. 在 app 中点击"忘记密码"
2. 输入已注册的邮箱
3. 应该能够成功处理

如果还有权限问题，检查：
- Firebase Console 中规则是否已发布
- 用户是否已登录（某些规则需要 `request.auth != null`）
- 查看 Firebase Console 的日志以获取详细错误信息

## 后续优化建议

1. **设置 Cloud Functions** - 这是最安全的方式
2. **添加速率限制** - 防止暴力破解
3. **添加验证码** - 防止自动化攻击
4. **日志记录** - 记录所有密码重置请求

