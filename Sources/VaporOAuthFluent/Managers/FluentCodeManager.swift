import Foundation
import FluentKit
import VaporOAuth

public struct FluentCodeManager: CodeManager {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func generateCode(userID: String, clientID: String, redirectURI: String, scopes: [String]?) async throws -> String {
        let codeString = [UInt8].random(count: 32).hex
        let fluentCode = FluentOAuthCode(codeID: codeString, clientID: clientID, redirectURI: redirectURI, userID: userID,
                                         expiryDate: Date().addingTimeInterval(60), scopes: scopes)
        try await fluentCode.save(on: database)
        return codeString
    }

    public func getCode(_ code: String) async throws -> OAuthCode? {
        return try await FluentOAuthCode.find(code, on: database)?.oAuthCode
    }

    public func codeUsed(_ code: OAuthCode) async throws {
        try await FluentOAuthCode.find(code.codeID, on: database)?.delete(on: database)
    }
}
