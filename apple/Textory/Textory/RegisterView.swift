import SwiftUI

struct RegisterView: View {
    var authStore: AuthStore

    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var acceptTerms = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .textContentType(.username)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                } footer: {
                    Text("Username: 3-32 characters, lowercase letters, digits, '_', '.', or '-'. Password: at least 10 characters.")
                }

                Section {
                    Toggle("I accept the Terms of Service", isOn: $acceptTerms)
                }

                if let errorMessage = authStore.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Register")
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: authStore.state) { _, newState in
                // Dismiss once we have a session (pending/rejected/approved
                // all mean the register call succeeded).
                switch newState {
                case .pending, .rejected, .approved:
                    dismiss()
                default:
                    break
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 320)
        #endif
    }

    private var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && acceptTerms
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        await authStore.register(username: username, password: password, acceptTerms: acceptTerms)
    }
}
