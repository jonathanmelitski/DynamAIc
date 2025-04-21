//
//  SettingsView.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/21/25.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject var vm = ApplicationViewModel.shared
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    
    var body: some View {
        VStack {
            Text("View")
            Button {
                Task {
                    do {
                        let gClientId = try ConfigurationKey.googleAPIKey.getString()
                        let verifier = AuthUtilities.codeVerifier()
                        let state = AuthUtilities.stateString()
                        let authUrlStr = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(gClientId)&redirect_uri=com.jmelitski.Dynamaic:oauth2Redirect&response_type=code&scope=\(AuthUtilities.googleScopesString)&code_challenge=\(AuthUtilities.codeChallenge(from: verifier))&code_challenge_method=S256&state=\(state)"
                        let urlWithToken = try await webAuthenticationSession.authenticate(
                            using: URL(string: authUrlStr)!,
                            callback: .customScheme("com.jmelitski.DynamAIc"),
                            additionalHeaderFields: [:]
                        )
                        
                        let code = AuthManager.codeFromUrl(urlWithToken)
                        guard let code else { return }
                        ApplicationViewModel.shared.accessTokens.append(try await AuthManager.getGoogleAccessToken(
                            authCode: code,
                            redirect: "com.jmelitski.Dynamaic:oauth2Redirect",
                            state: state,
                            verifier: verifier)
                        )
                        print(AuthManager.UserAPIServices.google.isLoggedIn)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            } label: {
                Text("Log in with Google")
                    .padding(4)
            }
            .buttonStyle(.borderedProminent)
        }
            .frame(width: 500, height: 300)
        
    }
}

#Preview {
    SettingsView()
}
