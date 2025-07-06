import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var showingRegistration = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                StyleConstants.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: StyleConstants.largeSpacing) {
                    Spacer()
                    
                    // 标题
                    VStack(spacing: StyleConstants.compactSpacing) {
                        Text("圣徒登录")
                            .font(StyleConstants.serifTitle(30, language: appState.selectedLanguage))
                            .foregroundColor(StyleConstants.goldColor)
                        
                        Text("请登录以访问教会内容")
                            .font(StyleConstants.sansFontBody(16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, StyleConstants.mediumSpacing)
                    
                    // 登录表单
                    VStack(spacing: StyleConstants.standardSpacing) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邮箱")
                                .font(StyleConstants.sansFontBody(14))
                                .foregroundColor(StyleConstants.goldColor)
                            
                            TextField("请输入邮箱地址", text: $email)
                                .font(StyleConstants.sansFontBody(16))
                                .foregroundColor(.white)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(StyleConstants.goldColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码")
                                .font(StyleConstants.sansFontBody(14))
                                .foregroundColor(StyleConstants.goldColor)
                            
                            HStack {
                                if isShowingPassword {
                                    TextField("请输入密码", text: $password)
                                        .font(StyleConstants.sansFontBody(16))
                                        .foregroundColor(.white)
                                } else {
                                    SecureField("请输入密码", text: $password)
                                        .font(StyleConstants.sansFontBody(16))
                                        .foregroundColor(.white)
                                }
                                
                                Button(action: {
                                    isShowingPassword.toggle()
                                }) {
                                    Image(systemName: isShowingPassword ? "eye.slash" : "eye")
                                        .foregroundColor(StyleConstants.goldColor.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(StyleConstants.goldColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 错误消息
                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .font(StyleConstants.sansFontBody(14))
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // 审核状态提示
                        if case .pending = authManager.authState {
                            VStack(spacing: StyleConstants.compactSpacing) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.orange)
                                    Text("账户正在审核中")
                                        .font(StyleConstants.sansFontBody(14))
                                        .foregroundColor(.orange)
                                }
                                Text("您的注册申请正在审核中，请耐心等待管理员审核通过")
                                    .font(StyleConstants.sansFontBody(12))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // 登录按钮
                        Button(action: {
                            authManager.signIn(email: email, password: password)
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#020f2e")))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("登录")
                                        .font(StyleConstants.sansFontBody(18))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, StyleConstants.standardSpacing)
                            .background(
                                (!email.isEmpty && !password.isEmpty) ? 
                                StyleConstants.goldColor : 
                                Color.gray.opacity(0.5)
                            )
                            .foregroundColor(Color(hex: "#020f2e"))
                            .cornerRadius(StyleConstants.buttonCornerRadius)
                        }
                        .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                    }
                    .padding(.horizontal, StyleConstants.containerPadding)
                    
                    Spacer()
                    
                    // 注册链接
                    VStack(spacing: StyleConstants.compactSpacing) {
                        Text("还没有账户？")
                            .font(StyleConstants.sansFontBody(16))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button(action: {
                            showingRegistration = true
                        }) {
                            Text("立即注册")
                                .font(StyleConstants.sansFontBody(16))
                                .fontWeight(.semibold)
                                .foregroundColor(StyleConstants.goldColor)
                        }
                    }
                    .padding(.bottom, StyleConstants.mediumSpacing)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRegistration) {
                RegistrationView()
                    .environmentObject(appState)
            }
            .onChange(of: authManager.authState) { newState in
                if case .signedIn(_) = newState {
                    // 登录成功，关闭登录页面
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onAppear {
                // 清除之前的错误消息
                authManager.clearError()
            }
        }
    }
}

// 预览
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppState())
    }
} 