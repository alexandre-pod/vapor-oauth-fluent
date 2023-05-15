import Foundation
import VaporOAuth
import FluentKit
import SQLKit

public final class FluentAccessToken: Model, AccessToken {
    public static let schema = "oauth_access_token"

    @ID(custom: "token_string", generatedBy: .user)
    public var id: String?

    @Field(key: "token_string")
    public var tokenString: String

    @Field(key: "client_id")
    public var clientID: String

    @OptionalField(key: "user_id")
    public var userID: String?

    @Field(key: "expiry_time")
    public var expiryTime: Date

    @OptionalField(key: "scopes")
    public var scopes: [String]?

    public init() {}

    public init(tokenString: String,
                clientID: String,
                userID: String?,
                expiryTime: Date,
                scopes: [String]?) {
        self.id = tokenString
        self.tokenString = tokenString
        self.clientID = clientID
        self.userID = userID
        self.expiryTime = expiryTime
        self.scopes = scopes
    }
}

extension FluentAccessToken {
    struct Create: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FluentAccessToken.schema)
                .compositeIdentifier(over: "token_string")
                .field("token_string", .string, .required)
                .field("client_id", .string, .required)
                .field("user_id", .string)
                .field("expiry_time", .date, .required)
                .field("scopes", .array(of: .string))
                .create()
            try await (database as? SQLDatabase)?
                .create(index: "oauth_access_token_index")
                .on(FluentAccessToken.schema)
                .column("token_string")
                .run()
        }

        func revert(on database: Database) async throws {
            try await (database as? SQLDatabase)?
                .drop(index: "oauth_access_token_index")
                .run()
            try await database.schema(FluentAccessToken.schema).delete()
        }
    }

    public static var migration: Migration {
        Create()
    }
}
