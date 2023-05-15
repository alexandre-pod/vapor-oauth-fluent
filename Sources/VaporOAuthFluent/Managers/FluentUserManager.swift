import Vapor
import FluentKit
import VaporOAuth

public struct FluentUserManager: UserManager {

    private let passwordHasher: PasswordHasher
    private let database: Database

    public init(passwordHasher: PasswordHasher, database: Database) {
        self.passwordHasher = passwordHasher
        self.database = database
    }

    public func authenticateUser(username: String, password: String) async throws -> String? {
        guard
            let user = try await FluentOAuthUser.find(username, on: database),
            try passwordHasher.verify(password, created: user.password)
        else {
            return nil
        }
        return user.id
    }

    public func getUser(userID: String) async throws -> OAuthUser? {
        return try await FluentOAuthUser.find(userID, on: database)?.oAuthUser
    }
}
