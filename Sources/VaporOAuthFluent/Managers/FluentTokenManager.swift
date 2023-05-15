import Foundation
import Vapor
import VaporOAuth
import FluentKit

public struct FluentTokenManager: TokenManager {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func getAccessToken(_ accessToken: String) async throws -> AccessToken? {
        return try await FluentAccessToken.find(accessToken, on: database)
    }

    public func getRefreshToken(_ refreshToken: String) async throws -> RefreshToken? {
        return try await FluentRefreshToken.find(refreshToken, on: database)
    }

    public func generateAccessToken(clientID: String, userID: String?, scopes: [String]?, expiryTime: Int) async throws -> AccessToken {
        let accessTokenString = [UInt8].random(count: 32).hex
        let accessToken = FluentAccessToken(tokenString: accessTokenString, clientID: clientID, userID: userID,
                                            expiryTime: Date().addingTimeInterval(TimeInterval(expiryTime)), scopes: scopes)
        try await accessToken.save(on: database)
        return accessToken
    }

    public func generateAccessRefreshTokens(clientID: String, userID: String?, scopes: [String]?,
                                            accessTokenExpiryTime: Int) async throws -> (AccessToken, RefreshToken) {
        let accessTokenString = [UInt8].random(count: 32).hex
        let accessToken = FluentAccessToken(tokenString: accessTokenString, clientID: clientID, userID: userID,
                                            expiryTime: Date().addingTimeInterval(TimeInterval(accessTokenExpiryTime)),
                                            scopes: scopes)
        try await accessToken.save(on: database)

        let refreshTokenString = [UInt8].random(count: 32).hex
        let refreshToken = FluentRefreshToken(tokenString: refreshTokenString, clientID: clientID, userID: userID, scopes: scopes)
        try await refreshToken.save(on: database)

        return (accessToken, refreshToken)
    }

    public func updateRefreshToken(_ refreshToken: RefreshToken, scopes: [String]) async throws {
        guard let refreshToken = try await FluentRefreshToken.find(refreshToken.tokenString, on: database) else {
            throw Abort(.internalServerError)
        }
        refreshToken.scopes = scopes
        try await refreshToken.update(on: database)
    }
}
