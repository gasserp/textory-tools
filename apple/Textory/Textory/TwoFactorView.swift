import SwiftUI

/// Step 2 of password login: the second factor.
///
/// Reached only when the server answered `POST /api/auth/login` with a
/// challenge instead of a session. The challenge lives in `AuthStore` and is
/// single-use with a five-minute life, so this screen is deliberately a
/// dead end apart from "verify" and "cancel" — there is nothing else it can do
/// with what it holds.
struct TwoFactorView: View {
    var authStore: AuthStore

    @State private var code = ""
    @State private var usingRecoveryCode = false
    @State private var isSubmitting = false

    /// A recovery code is exactly 32 characters, but the cap is looser: a paste
    /// carrying a leading or trailing space would otherwise be truncated before
    /// `AuthStore` strips the whitespace, and the user would be told a correct
    /// code was invalid.
    private var maxLength: Int { usingRecoveryCode ? 40 : 7 }

    var body: some View {
        VStack(spacing: 16) {
            Text("Two-Factor Authentication")
                .font(.title2)
                .bold()

            Text(usingRecoveryCode
                 ? "Enter one of your recovery codes."
                 : "Enter the 6-digit code from your authenticator app.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            TextField(usingRecoveryCode ? "Recovery code" : "Code", text: $code)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(usingRecoveryCode ? .asciiCapable : .numberPad)
                #endif
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .onChange(of: code) { _, newValue in
                    if newValue.count > maxLength {
                        code = String(newValue.prefix(maxLength))
                    }
                }

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
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSubmitting)

            Button(usingRecoveryCode ? "Use an authenticator code" : "Use a recovery code instead") {
                usingRecoveryCode.toggle()
                code = ""
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)

            Button("Cancel") {
                code = ""
                usingRecoveryCode = false
                authStore.cancelSecondFactor()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isSubmitting)
        }
        .padding()
        .frame(maxWidth: 360)
        .onSubmit {
            Task { await submit() }
        }
    }

    private var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() async {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        await authStore.submitSecondFactor(code)
        // Never leave a spent code in the field: every code here is single-use,
        // so re-submitting the same one can only fail.
        code = ""
    }
}
