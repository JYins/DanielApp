import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var newPassword = ""
    @State private var isShowingPassword = false
    @State private var isProcessing = false
    @State private var showSuccessMessage = false
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                StyleConstants.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: StyleConstants.largeSpacing) {
                        Spacer().frame(height: 20)
                        
                        // 标题
                        VStack(spacing: StyleConstants.compactSpacing) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 50))
                                .foregroundColor(DesignSystem.Colors.accent)
                                .padding(.bottom, 8)
                            
                            Text("忘记密码")
                                .font(StyleConstants.serifTitle(28, language: appState.selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            Text("请输入您的注册邮箱，我们将发送密码重置链接")
                                .font(StyleConstants.sansFontBody(15, language: appState.selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.bottom, StyleConstants.mediumSpacing)
                        
                        // 表单
                        VStack(spacing: StyleConstants.standardSpacing) {
                            // 邮箱输入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("邮箱")
                                    .font(StyleConstants.sansFontBody(14, language: appState.selectedLanguage))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                TextField("请输入注册邮箱", text: $email)
                                    .font(StyleConstants.sansFontBody(16, language: appState.selectedLanguage))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )
                            }
                            
                            // 状态消息
                            if showSuccessMessage {
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(isSuccess ? .green : .red)
                                        Text(isSuccess ? "处理成功" : "处理失败")
                                            .font(StyleConstants.sansFontBody(14, language: appState.selectedLanguage))
                                            .foregroundColor(isSuccess ? .green : .red)
                                    }
                                    
                                    Text(statusMessage)
                                        .font(StyleConstants.sansFontBody(13, language: appState.selectedLanguage))
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .background((isSuccess ? Color.green : Color.red).opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // 提交按钮
                            Button(action: {
                                resetPassword()
                            }) {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("处理中...")
                                            .font(StyleConstants.sansFontBody(18, language: appState.selectedLanguage))
                                            .fontWeight(.semibold)
                                    } else {
                                        Text("重置密码")
                                            .font(StyleConstants.sansFontBody(18, language: appState.selectedLanguage))
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, StyleConstants.standardSpacing)
                                .background(!email.isEmpty && !isProcessing ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                                .foregroundColor(.white)
                                .cornerRadius(StyleConstants.buttonCornerRadius)
                            }
                            .disabled(email.isEmpty || isProcessing)
                            
                            // 返回登录
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("返回登录")
                                    .font(StyleConstants.sansFontBody(16, language: appState.selectedLanguage))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                        }
                        .padding(.horizontal, StyleConstants.containerPadding)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func resetPassword() {
        isProcessing = true
        showSuccessMessage = false
        
        authManager.resetPassword(email: email, newPassword: "") { success, message in
            isProcessing = false
            isSuccess = success
            statusMessage = message ?? (success ? "密码重置成功" : "密码重置失败")
            showSuccessMessage = true
            
            if success {
                // 3秒后自动返回登录页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// 预览
struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView()
            .environmentObject(AppState())
    }
}

