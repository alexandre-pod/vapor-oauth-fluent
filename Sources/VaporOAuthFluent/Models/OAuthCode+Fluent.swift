import Foundation
import VaporOAuth
import FluentKit
import SQLKit

public final class FluentOAuthCode: Model {
    public static let schema = "oauth_code"

    @ID(custom: "code_string", generatedBy: .user)
    public var id: String?

    @Field(key: "code_string")
    public var codeID: String

    @Field(key: "client_id")
    public var clientID: String

    @Field(key: "redirect_uri")
    public var redirectURI: String

    @Field(key: "user_id")
    public var userID: String

    @Field(key: "expiry_date")
    public var expiryDate: Date

    @OptionalField(key: "scopes")
    public var scopes: [String]?

    public init() {}

    public init(codeID: String,
                clientID: String,
                redirectURI: String,
                userID: String,
                expiryDate: Date,
                scopes: [String]?) {
        self.id = codeID
        self.codeID = codeID
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.userID = userID
        self.expiryDate = expiryDate
        self.scopes = scopes
    }
}

extension FluentOAuthCode {
    public var oAuthCode: OAuthCode {
        OAuthCode(
            codeID: codeID,
            clientID: clientID,
            redirectURI: redirectURI,
            userID: userID,
            expiryDate: expiryDate,
            scopes: scopes
        )
    }
}

extension FluentOAuthCode {
    struct Create: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FluentOAuthCode.schema)
                .compositeIdentifier(over: "code_string")
                .field("code_string", .string, .required)
                .field("client_id", .string, .required)
                .field("redirect_uri", .string, .required)
                .field("user_id", .string, .required)
                .field("expiry_date", .date, .required)
                .field("scopes", .array(of: .string))
                .create()
            try await (database as? SQLDatabase)?
                .create(index: "oauth_code_index")
                .on(FluentOAuthCode.schema)
                .column("code_string")
                .run()
        }

        func revert(on database: Database) async throws {
            try await (database as? SQLDatabase)?
                .drop(index: "oauth_code_index")
                .run()
            try await database.schema(FluentOAuthCode.schema).delete()
        }
    }

    public static var migration: Migration {
        Create()
    }
}
