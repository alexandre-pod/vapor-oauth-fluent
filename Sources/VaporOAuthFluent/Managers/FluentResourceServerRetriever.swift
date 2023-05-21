import VaporOAuth
import FluentKit

public struct FluentResourceServerRetriever: ResourceServerRetriever {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func getServer(_ username: String) async throws -> OAuthResourceServer? {
        return try await FluentOAuthResourceServer.find(username, on: database)?.oAuthResourceServer
    }
}
