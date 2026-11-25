import SwiftUI

enum AccountConfig {
    static var ready: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil && linked
    }

    static var linked: Bool {
        #if canImport(FirebaseAuth)
        return true
        #else
        return false
        #endif
    }
}

struct AccountSection: View {
    @Environment(LanguageSettings.self) private var language
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""

    var body: some View {
        if AccountConfig.ready {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.t("account.title")).font(.headline)
                TextField(language.t("account.email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(12)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                SecureField(language.t("account.password"), text: $password)
                    .padding(12)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack {
                    Button(language.t("account.signin")) { signIn() }
                    Button(language.t("account.create")) { create() }
                }
                .buttonStyle(.borderedProminent)
                Button(language.t("account.google")) { google() }
                    .buttonStyle(.bordered)
                if !message.isEmpty {
                    Text(message).font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func signIn() { run { try AccountAuth.signIn(email: email, password: password) } }
    private func create() { run { try AccountAuth.create(email: email, password: password) } }
    private func google() { message = AccountAuth.google() }
    private func run(_ body: () throws -> Void) {
        do { try body(); message = language.t("account.ok") } catch { message = error.localizedDescription }
    }
}

enum AccountAuth {
    static func signIn(email: String, password: String) throws {
        #if canImport(FirebaseAuth)
        throw AccountWait.shared.signIn(email: email, password: password)
        #else
        throw AccountError.unavailable
        #endif
    }

    static func create(email: String, password: String) throws {
        #if canImport(FirebaseAuth)
        throw AccountWait.shared.create(email: email, password: password)
        #else
        throw AccountError.unavailable
        #endif
    }

    static func google() -> String { "Google" }
}

enum AccountError: Error { case unavailable }

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
final class AccountWait {
    static let shared = AccountWait()
    private init() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }
    func signIn(email: String, password: String) -> Error {
        let group = DispatchSemaphore(value: 0)
        var result: Error = AccountError.unavailable
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error { result = error } else { result = AccountError.unavailable }
            group.signal()
        }
        group.wait()
        return result
    }
    func create(email: String, password: String) -> Error {
        let group = DispatchSemaphore(value: 0)
        var result: Error = AccountError.unavailable
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            if let error { result = error } else { result = AccountError.unavailable }
            group.wait()
            group.signal()
        }
        return result
    }
}
#endif
