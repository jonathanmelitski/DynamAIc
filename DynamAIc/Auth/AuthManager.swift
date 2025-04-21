//
//  AuthManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/21/25.
//
import Foundation

struct AuthManager {
    
    static func codeFromUrl(_ url: URL) -> String? {
        guard let comps = URLComponents(string: url.absoluteString), let code = comps.queryItems?.first(where: { $0.name == "code"})?.value else {
            return nil
        }
        
        return code
    }
    
    static func getGoogleAccessToken(authCode: String, redirect: String, state: String, verifier: String) async throws -> GoogleAccessToken {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String:String] = [
            "client_id": try ConfigurationKey.googleAPIKey.getString(),
            "code": authCode,
            "state": state,
            "redirect_uri": redirect,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        let parameterArray = parameters.map { "\($0.key)=\($0.value)" }
        let postString = parameterArray.joined(separator: "&")
        let postData = postString.data(using: .utf8)
        request.httpBody = postData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.failedToFetchToken
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        
        return try dec.decode(GoogleAccessToken.self, from: data)
    }
    
    
    enum UserAPIServices {
        case google
        
        var isLoggedIn: Bool {
            switch self {
            case .google:
                return !ApplicationViewModel.shared.accessTokens.filter({ $0 is GoogleAccessToken }).isEmpty
            }
        }
    }
    
}

enum AuthError: Error {
    case failedToFetchToken
}

struct GoogleAccessToken: AccessToken {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String
    let tokenType: String
    let idToken: String
    let refreshTokenExpiresIn: Int
}

protocol AccessToken: Codable {
    var accessToken: String { get }
    var expiresIn: Int { get }
    var refreshToken: String { get }
    var tokenType: String { get }
}
