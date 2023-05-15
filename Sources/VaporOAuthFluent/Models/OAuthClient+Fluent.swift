import Foundation
import VaporOAuth
import FluentKit
import SQLKit

extension OAuthFlowType: Codable {}

public final class FluentOAuthClient: Model {
    public static let schema = "oauth_clients"

    @ID(custom: "client_id", generatedBy: .user)
    public var id: String?

    @Field(key: "client_id")
    public var clientID: String

    @OptionalField(key: "redirect_uris")
    public var redirectURIs: [String]?

    @OptionalField(key: "client_secret")
    public var clientSecret: String?

    @OptionalField(key: "scopes")
    public var validScopes: [String]?

    @OptionalField(key: "confidential_client")
    public var confidentialClient: Bool?

    @Field(key: "first_party")
    public var firstParty: Bool

    @Field(key: "allowed_grant_type")
    public var allowedGrantType: OAuthFlowType

    public init() {}

    public init(clientID: String,
                redirectURIs: [String]?,
                clientSecret: String?,
                validScopes: [String]?,
                confidentialClient: Bool?,
                firstParty: Bool,
                allowedGrantType: OAuthFlowType) {
        self.id = clientID
        self.clientID = clientID
        self.redirectURIs = redirectURIs
        self.clientSecret = clientSecret
        self.validScopes = validScopes
        self.confidentialClient = confidentialClient
        self.firstParty = firstParty
        self.allowedGrantType = allowedGrantType
    }
}

extension FluentOAuthClient {
    public var oAuthClient: OAuthClient {
        return OAuthClient(
            clientID: clientID,
            redirectURIs: redirectURIs,
            clientSecret: clientSecret,
            validScopes: validScopes,
            confidential: confidentialClient,
            firstParty: firstParty,
            allowedGrantType: allowedGrantType
        )
    }
}

extension FluentOAuthClient {
    struct Create: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FluentOAuthClient.schema)
                .compositeIdentifier(over: "client_id")
                .field("client_id", .string, .required)
                .field("redirect_uris", .array(of: .string))
                .field("client_secret", .string)
                .field("scopes", .array(of: .string))
                .field("confidential_client", .bool)
                .field("first_party", .bool, .required)
                .field("allowed_grant_type", .string, .required)
                .create()
            try await (database as? SQLDatabase)?
                .create(index: "oauth_client_index")
                .on(FluentOAuthClient.schema)
                .column("client_id")
                .run()
        }

        func revert(on database: Database) async throws {
            try await (database as? SQLDatabase)?
                .drop(index: "oauth_client_index")
                .run()
            try await database.schema(FluentOAuthClient.schema).delete()
        }
    }

    public static var migration: Migration {
        Create()
    }
}
