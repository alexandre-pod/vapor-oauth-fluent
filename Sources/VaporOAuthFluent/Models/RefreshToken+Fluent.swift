import Foundation
import VaporOAuth
import FluentKit
import SQLKit

public final class FluentRefreshToken: Model, RefreshToken {
    public static let schema = "oauth_refresh_token"

    @ID(custom: "refresh_token_string", generatedBy: .user)
    public var id: String?

    @Field(key: "refresh_token_string")
    public var tokenString: String

    @Field(key: "client_id")
    public var clientID: String

    @OptionalField(key: "user_id")
    public var userID: String?

    @OptionalField(key: "scopes")
    public var scopes: [String]?

    public init() {}

    public init(tokenString: String,
                clientID: String,
                userID: String?,
                scopes: [String]?) {
        self.id = tokenString
        self.tokenString = tokenString
        self.clientID = clientID
        self.userID = userID
        self.scopes = scopes
    }
}

extension FluentRefreshToken {
    struct Create: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FluentRefreshToken.schema)
                .compositeIdentifier(over: "refresh_token_string")
                .field("refresh_token_string", .string, .required)
                .field("client_id", .string, .required)
                .field("user_id", .string)
                .field("scopes", .array(of: .string))
                .create()
            try await (database as? SQLDatabase)?
                .create(index: "oauth_refresh_token_index")
                .on(FluentRefreshToken.schema)
                .column("refresh_token_string")
                .run()
        }

        func revert(on database: Database) async throws {
            try await (database as? SQLDatabase)?
                .drop(index: "oauth_refresh_token_index")
                .run()
            try await database.schema(FluentRefreshToken.schema).delete()
        }
    }

    public static var migration: Migration {
        Create()
    }
}
