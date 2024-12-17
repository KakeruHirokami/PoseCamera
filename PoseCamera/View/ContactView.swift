//
//  ContactView.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/12/15.
//

import SwiftUI
import UIKit
import MessageUI

struct ContactView: View {
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""
    
    // フォーム送信後の結果表示用
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack {
            Text("アプリについてのご質問や機能リクエストなどございましたら、気軽に下記のフォームよりお問い合わせください")
            Form {
                Section(header: Text("お名前")) {
                    TextField("お名前を入力", text: $name)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("メールアドレス")) {
                    TextField("example@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("お問い合わせ内容")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button(action: {
                        submitForm()
                    }) {
                        Text("送信")
                    }
                }
            }
            .navigationBarTitle("お問い合わせ", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("送信結果"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    /// Send request
    private func submitForm() {
        // Validation
        guard !name.isEmpty else {
            alertMessage = "お名前を入力してください。"
            showAlert = true
            return
        }
        
        guard !email.isEmpty, isValidEmail(email) else {
            alertMessage = "有効なメールアドレスを入力してください。"
            showAlert = true
            return
        }
        
        guard !message.isEmpty else {
            alertMessage = "お問い合わせ内容を入力してください。"
            showAlert = true
            return
        }
        
        // ここで実際の送信処理を行う
        
        alertMessage = "お問い合わせを送信しました。"
        showAlert = true
        
        clearForm()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let predicate = NSPredicate(format:"SELF MATCHES[c] %@", emailPattern)
        return predicate.evaluate(with: email)
    }
    
    /// 入力リセット
    private func clearForm() {
        name = ""
        email = ""
        message = ""
    }
}
