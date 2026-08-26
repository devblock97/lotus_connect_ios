//
//  HTTPClient.swift
//  lotus_connect_ios
//
//  Created by Nguyen Nhut Thong on 12/8/26.
//

import Dependencies
import DependenciesMacros
import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public enum HTTPError: Error, Equatable, Sendable {
    case invalidURL
    case badResponse(statusCode: Int, message: String?)
    case unauthorized
    case decodingFailed
    case networkError(String)
}

@DependencyClient
public struct HTTPClient: Sendable {
    public var send: @Sendable (
        _ path: String,
        _ method: HTTPMethod,
        _ body: Data?,
        _ headers: [String: String]?
    ) async throws -> Data
    
    public func request<T: Decodable & Sendable>(
        _ path: String,
        _ method: HTTPMethod,
        _ body: (any Encodable & Sendable)?,
        _ headers: [String: String]?
    ) async throws -> T {
        var bodyData: Data? = nil
        if let body = body {
            bodyData = try JSONEncoder().encode(body)
        }
        
        let rawData = try await self.send(
            path: path,
            method: method,
            body: bodyData,
            headers: headers
        )
        
        do {
            let decoder = JSONDecoder()
            decoder.dataDecodingStrategy = .base64
            return try decoder.decode(T.self, from: rawData)
        } catch {
            throw HTTPError.decodingFailed
        }
    }
}

extension HTTPClient: DependencyKey {
    public static let liveValue: HTTPClient = {
        @Dependency(KeychainClient.self) var keychainClient

        let baseURL = URL(string: "https://ef21-2001-ee0-26e-7703-64c2-be98-cc71-71d6.ngrok-free.app/api/v1")!
        
        return HTTPClient(
            send: { path, method, bodyData, customHeaders in
                
                guard var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
                    throw HTTPError.invalidURL
                }
                
                if let queryIndex = path.firstIndex(of: "?") {
                    let pathPart = String(path[..<queryIndex])
                    let queryPart = String(path[path.index(after: queryIndex)...])
                    
                    let cleanPathPart = pathPart.hasPrefix("/") ? String(pathPart.dropFirst()) : pathPart
                    urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(cleanPathPart)

                } else {
                    let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
                    urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(cleanPath)
                }
                
                guard let finalURL = urlComponents.url else {
                    throw HTTPError.invalidURL
                }
                
                
                var urlRequest = URLRequest(url: finalURL)
                urlRequest.httpMethod = method.rawValue
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                
                if let session = try? await keychainClient.loadSession() {
                    urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                }
                
                if let customHeaders = customHeaders {
                    for (key, value) in customHeaders {
                        urlRequest.setValue(value, forHTTPHeaderField: key)
                    }
                }
                
                urlRequest.httpBody = bodyData
                
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HTTPError.networkError("Invalid HTTP response.")
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        try? await keychainClient.clearSession()
                        throw HTTPError.unauthorized
                    }
                    let errorMessage = String(data: data, encoding: .utf8)
                    throw HTTPError.badResponse(statusCode: httpResponse.statusCode, message: errorMessage)
                }
                return data
            }
        )
    }()
}

extension DependencyValues {
    public var httpClient: HTTPClient {
        get { self[HTTPClient.self] }
        set { self[HTTPClient.self] = newValue }
    }
}
