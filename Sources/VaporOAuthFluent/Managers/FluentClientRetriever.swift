import VaporOAuth
import FluentKit

public struct FluentClientRetriever: ClientRetriever {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func getClient(clientID: String) async throws -> OAuthClient? {
        return try await FluentOAuthClient.find(clientID, on: database)?.oAuthClient
    }
}
