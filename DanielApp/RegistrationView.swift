import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @State private var formData = RegistrationFormData()
    @State private var showingDatePicker = false
    @State private var datePickerType: DatePickerType = .birth
    @State private var isShowingPassword = false
    @State private var isShowingConfirmPassword = false
    @Environment(\.presentationMode) var presentationMode
    
    enum DatePickerType {
        case birth, salvation
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                StyleConstants.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: StyleConstants.standardSpacing) {
                        // 标题
                        Text("圣徒注册")
                            .font(StyleConstants.serifTitle(28, language: appState.selectedLanguage))
                            .foregroundColor(StyleConstants.goldColor)
                            .padding(.top, StyleConstants.standardSpacing)
                        
                        Text("请填写以下信息完成注册")
                            .font(StyleConstants.sansFontBody(16))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, StyleConstants.compactSpacing)
                        
                        // 基本信息部分
                        VStack(alignment: .leading, spacing: StyleConstants.standardSpacing) {
                            SectionHeader(title: "基本信息")
                            
                            // 姓名
                            CustomTextField(
                                title: "姓名",
                                text: $formData.name,
                                placeholder: "请输入您的姓名"
                            )
                            
                            // 出生年月日
                            DateInputField(
                                title: "出生年月日",
                                date: formData.birthDate,
                                placeholder: "请选择出生日期"
                            ) {
                                datePickerType = .birth
                                showingDatePicker = true
                            }
                            
                            // 地址
                            CustomTextField(
                                title: "地址",
                                text: $formData.address,
                                placeholder: "请输入您的地址"
                            )
                            
                            // 邮箱
                            CustomTextField(
                                title: "邮箱",
                                text: $formData.email,
                                placeholder: "请输入邮箱地址",
                                keyboardType: .emailAddress
                            )
                            
                            // 手机号
                            CustomTextField(
                                title: "联系方式（手机）",
                                text: $formData.phoneNumber,
                                placeholder: "请输入手机号码",
                                keyboardType: .phonePad
                            )
                            
                            // 密码
                            CustomSecureField(
                                title: "密码",
                                text: $formData.password,
                                placeholder: "请输入密码（至少6位）",
                                isSecure: !isShowingPassword
                            ) {
                                isShowingPassword.toggle()
                            }
                            
                            // 确认密码
                            CustomSecureField(
                                title: "确认密码",
                                text: $formData.confirmPassword,
                                placeholder: "请再次输入密码",
                                isSecure: !isShowingConfirmPassword
                            ) {
                                isShowingConfirmPassword.toggle()
                            }
                            
                            // 密码匹配提示
                            if !formData.password.isEmpty && !formData.confirmPassword.isEmpty {
                                HStack {
                                    Image(systemName: formData.passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(formData.passwordsMatch ? .green : .red)
                                    Text(formData.passwordsMatch ? "密码匹配" : "密码不匹配")
                                        .font(StyleConstants.sansFontBody(12))
                                        .foregroundColor(formData.passwordsMatch ? .green : .red)
                                }
                                .padding(.horizontal, StyleConstants.standardSpacing)
                            }
                        }
                        
                        // 信仰信息部分
                        VStack(alignment: .leading, spacing: StyleConstants.standardSpacing) {
                            SectionHeader(title: "信仰信息")
                            
                            // 教会所在国家
                            CustomTextField(
                                title: "教会所在国家",
                                text: $formData.churchCountry,
                                placeholder: "请输入教会所在国家"
                            )
                            
                            // 教会名称
                            CustomTextField(
                                title: "教会名称",
                                text: $formData.churchName,
                                placeholder: "请输入教会名称"
                            )
                            
                            // 得救年月日
                            DateInputField(
                                title: "得救年月日",
                                date: formData.salvationDate,
                                placeholder: "请选择得救日期"
                            ) {
                                datePickerType = .salvation
                                showingDatePicker = true
                            }
                            
                            // 侍奉部署（可选）
                            CustomTextField(
                                title: "侍奉部署（可选）",
                                text: $formData.ministryDepartment,
                                placeholder: "如有侍奉部署请填写"
                            )
                            
                            // 圣徒信息确认人员
                            CustomTextField(
                                title: "圣徒信息确认人员",
                                text: $formData.confirmationPerson,
                                placeholder: "如：首尔中央教会青年会部长000"
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
                        
                        // 注册按钮
                        Button(action: {
                            authManager.register(with: formData)
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#020f2e")))
                                        .scaleEffect(0.8)
                                } else if authManager.authState.isPending {
                                    HStack {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("注册成功！")
                                            .font(StyleConstants.sansFontBody(18))
                                            .fontWeight(.semibold)
                                    }
                                } else {
                                    Text("注册")
                                        .font(StyleConstants.sansFontBody(18))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, StyleConstants.standardSpacing)
                            .background(
                                authManager.authState.isPending ? Color.green :
                                (formData.isValid ? StyleConstants.goldColor : Color.gray.opacity(0.5))
                            )
                            .foregroundColor(Color(hex: "#020f2e"))
                            .cornerRadius(StyleConstants.buttonCornerRadius)
                        }
                        .disabled(!formData.isValid || authManager.isLoading || authManager.authState.isPending)
                        
                        // 返回登录
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("已有账户？返回登录")
                                .font(StyleConstants.sansFontBody(16))
                                .foregroundColor(StyleConstants.goldColor)
                        }
                        .padding(.bottom, StyleConstants.mediumSpacing)
                    }
                    .padding(.horizontal, StyleConstants.containerPadding)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: datePickerType == .birth ? $formData.birthDate : $formData.salvationDate,
                    title: datePickerType == .birth ? "选择出生日期" : "选择得救日期"
                )
            }
            .onChange(of: authManager.authState) { newState in
                if case .pending = newState {
                    // 注册成功，显示成功消息后返回到登录页面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// 自定义文本输入框
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StyleConstants.sansFontBody(14))
                .foregroundColor(StyleConstants.goldColor)
            
            TextField(placeholder, text: $text)
                .font(StyleConstants.sansFontBody(16))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(StyleConstants.goldColor.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// 自定义密码输入框
struct CustomSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StyleConstants.sansFontBody(14))
                .foregroundColor(StyleConstants.goldColor)
            
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(StyleConstants.sansFontBody(16))
                        .foregroundColor(.white)
                } else {
                    TextField(placeholder, text: $text)
                        .font(StyleConstants.sansFontBody(16))
                        .foregroundColor(.white)
                }
                
                Button(action: toggleAction) {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
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
    }
}

// 日期输入框
struct DateInputField: View {
    let title: String
    let date: Date
    let placeholder: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StyleConstants.sansFontBody(14))
                .foregroundColor(StyleConstants.goldColor)
            
            Button(action: action) {
                HStack {
                    Text(DateFormatter.displayFormatter.string(from: date))
                        .font(StyleConstants.sansFontBody(16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .foregroundColor(StyleConstants.goldColor.opacity(0.7))
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
        }
    }
}

// 日期选择器弹窗
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let title: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    title,
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 分区标题
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(StyleConstants.serifTitle(20, language: .chinese))
                .foregroundColor(StyleConstants.goldColor)
            
            Spacer()
        }
        .padding(.top, StyleConstants.standardSpacing)
        .padding(.bottom, StyleConstants.compactSpacing)
    }
}

// 日期格式化器
extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

// 预览
struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
            .environmentObject(AppState())
    }
} 