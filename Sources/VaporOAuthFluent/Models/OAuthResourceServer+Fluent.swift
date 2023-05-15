import VaporOAuth
import FluentKit
import SQLKit

public final class FluentOAuthResourceServer: Model {
    public static let schema = "oauth_resource_server"

    @ID(custom: "username", generatedBy: .user)
    public var id: String?

    @Field(key: "username")
    public var username: String

    @Field(key: "password")
    public var password: String

    public init() {}

    public init(username: String,
                password: String) {
        self.id = username
        self.username = username
        self.password = password
    }
}

extension FluentOAuthResourceServer {
    public var oAuthResourceServer: OAuthResourceServer {
        OAuthResourceServer(
            username: username,
            password: password
        )
    }
}

extension FluentOAuthResourceServer {
    struct Create: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(FluentOAuthResourceServer.schema)
                .compositeIdentifier(over: "username")
                .field("username", .string, .required)
                .field("password", .string, .required)
                .create()
            try await (database as? SQLDatabase)?
                .create(index: "oauth_resource_server_index")
                .on(FluentOAuthResourceServer.schema)
                .column("username")
                .run()
        }

        func revert(on database: Database) async throws {
            try await (database as? SQLDatabase)?
                .drop(index: "oauth_resource_server_index")
                .run()
            try await database.schema(FluentOAuthResourceServer.schema).delete()
        }
    }

    public static var migration: Migration {
        Create()
    }
}
