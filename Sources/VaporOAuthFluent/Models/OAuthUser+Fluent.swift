import Vapor
import VaporOAuth
import FluentKit
import SQLKit

public final class FluentOAuthUser: Model {
    public static let schema = "oauth_user"

    @ID(custom: "username", generatedBy: .user)
    public var id: String?

    @Field(key: "username")
    public var username: String

    @OptionalField(key: "email_address")
    public var emailAddress: String?

    @Field(key: "password")
    public var password: String

    public init() {}

    public init(username: String,
                emailAddress: String?,
                password: String) {
        self.id = username
        self.username = username
        self.emailAddress = emailAddress
        self.password = password
    }
}

extension FluentOAuthUser {
    public var oAuthUser: OAuthUser {
        OAuthUser(
            userID: id,
            username: username,
            emailAddress: emailAddress,
            password: password
        )
    }
}

extension FluentOAuthUser {
    struct Create: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FluentOAuthUser.schema)
                .compositeIdentifier(over: "username")
                .field("username", .string, .required)
                .field("email_address", .string)
                .field("password", .string, .required)
                .create()
            try await (database as? SQLDatabase)?
                .create(index: "oauth_user_index")
                .on(FluentOAuthUser.schema)
                .column("username")
                .run()
        }

        func revert(on database: Database) async throws {
            try await (database as? SQLDatabase)?
                .drop(index: "oauth_user_index")
                .run()
            try await database.schema(FluentOAuthUser.schema).delete()
        }
    }

    public static var migration: Migration {
        Create()
    }
}

extension OAuthUser: SessionAuthenticatable {
    public var sessionID: String {
        self.username
    }
}
