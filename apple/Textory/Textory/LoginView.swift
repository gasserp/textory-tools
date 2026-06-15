import SwiftUI

struct LoginView: View {
    var authStore: AuthStore

    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var showRegister = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Textory")
                .font(.largeTitle)
                .bold()

            TextField("Username", text: $username)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .textContentType(.username)

            SecureField("Password", text: $password)
                .textContentType(.password)

            if let errorMessage = authStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSubmitting)

            Button("Create an account") {
                showRegister = true
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: 360)
        .sheet(isPresented: $showRegister) {
            RegisterView(authStore: authStore)
        }
        .onSubmit {
            Task { await submit() }
        }
    }

    private var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        await authStore.login(username: username, password: password)
    }
}
