import XCTest
import XCTVapor
import VaporOAuthFluent
import VaporOAuth
import Vapor
import FluentKit
import Fluent
import FluentSQLiteDriver

final class VaporOAuthFluentTests: XCTestCase {

    // MARK: - Properties

    var app: Application!
    let capturingAuthHandler = CapturingAuthHandler()
    let scope = "email"
    let redirectURI = "https://api.brokenhands.io/callback"
    let clientID = "ABCDEFG"
    let passwordClientID = "1234567890"
    let clientSecret = "1234"
    let email = "han@therebelalliance.com"
    let username = "han"
    let password = "leia"
    var user: OAuthUser!
    var oauthClient: OAuthClient!
    var passwordClient: OAuthClient!
    var resourceServer: OAuthResourceServer!

    // MARK: - Overrides

    override func setUp() async throws {
        app = Application(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        let userManager = FluentUserManager(passwordHasher: app.password, database: app.db)
        let tokenManager = FluentTokenManager(database: app.db)

        let provider = VaporOAuth.OAuth2(
            codeManager: FluentCodeManager(database: app.db),
            tokenManager: tokenManager,
            clientRetriever: FluentClientRetriever(database: app.db),
            authorizeHandler: capturingAuthHandler,
            userManager: userManager,
            validScopes: [scope],
            resourceServerRetriever: FluentResourceServerRetriever(database: app.db),
            oAuthHelper: .local(
                tokenAuthenticator: TokenAuthenticator(),
                userManager: userManager,
                tokenManager: tokenManager
            )
        )

        app.lifecycle.use(provider)
        try app.register(collection: TestResourceController())

        app.migrations.add(FluentOAuthClient.migration)
        app.migrations.add(FluentOAuthUser.migration)
        app.migrations.add(FluentOAuthCode.migration)
        app.migrations.add(FluentAccessToken.migration)
        app.migrations.add(FluentRefreshToken.migration)
        app.migrations.add(FluentOAuthResourceServer.migration)

        try await app.autoMigrate()

        app.middleware.use(app.sessions.middleware)
        app.middleware.use(UserSessionAuthenticator())

        let passwordHash = try app.password.hash(password)
        let fluentUser = FluentOAuthUser(username: username, emailAddress: email, password: passwordHash)
        try await fluentUser.save(on: app.db)
        user = fluentUser.oAuthUser

        let fluentOAuthClient = FluentOAuthClient(clientID: clientID, redirectURIs: [redirectURI], clientSecret: clientSecret,
                                                  validScopes: [scope], confidentialClient: true, firstParty: true,
                                                  allowedGrantType: .authorization)
        try await fluentOAuthClient.save(on: app.db)
        oauthClient = fluentOAuthClient.oAuthClient

        let fluentPasswordClient = FluentOAuthClient(clientID: passwordClientID, redirectURIs: [redirectURI], clientSecret: clientSecret,
                                                     validScopes: [scope], confidentialClient: true, firstParty: true,
                                                     allowedGrantType: .password)
        try await fluentPasswordClient.save(on: app.db)
        passwordClient = fluentPasswordClient.oAuthClient

        let fluentResourceServer = FluentOAuthResourceServer(username: username, password: password)
        try await fluentResourceServer.save(on: app.db)
        resourceServer = fluentResourceServer.oAuthResourceServer
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        app.shutdown()
    }

    // MARK: - Tests

    func testThatAuthCodeFlowWorksAsExpectedWithFluentModels() async throws {

        // Get Auth Code

        let state = "jfeiojo382497329"

        var queries: [String] = []
        queries.append("response_type=code")
        queries.append("client_id=\(clientID)")
        queries.append("redirect_uri=\(redirectURI)")
        queries.append("scope=\(scope)")
        queries.append("state=\(state)")

        let requestQuery = queries.joined(separator: "&")

        capturingAuthHandler.authenticateRequestWithUser = user

        let response = try await app.sendRequest(.GET, "/oauth/authorize?\(requestQuery)")

        let sessionCookie = try XCTUnwrap(response.headers.setCookie)

        XCTAssertEqual(capturingAuthHandler.responseType, "code")
        XCTAssertEqual(capturingAuthHandler.clientID, clientID)
        XCTAssertEqual(capturingAuthHandler.redirectURI?.description, URI(string: redirectURI).description)
        XCTAssertEqual(capturingAuthHandler.scope?.count, 1)
        XCTAssertTrue(capturingAuthHandler.scope?.contains(scope) ?? false)
        XCTAssertEqual(capturingAuthHandler.state, state)
        XCTAssertEqual(response.status, .ok)

        var codeQueries: [String] = []

        codeQueries.append("client_id=\(clientID)")
        codeQueries.append("redirect_uri=\(redirectURI)")
        codeQueries.append("state=\(state)")
        codeQueries.append("scope=\(scope)")
        codeQueries.append("response_type=code")

        let codeQuery = codeQueries.joined(separator: "&")

        struct AuthozizeCodeRequest: Content {
            let applicationAuthorized: Bool
            let csrfToken: String?
        }

        let codeResponse = try await app.sendRequest(.POST, "/oauth/authorize?\(codeQuery)") { request async throws in
            request.headers.cookie = sessionCookie
            try request.content.encode(AuthozizeCodeRequest(
                applicationAuthorized: true,
                csrfToken: capturingAuthHandler.csrfToken
            ))
        }

        let newLocation = try XCTUnwrap(codeResponse.headers[.location].first)

        let codeRedirectURI = URI(string: newLocation)

        let query = try XCTUnwrap(codeRedirectURI.query)

        let queryParts = query.components(separatedBy: "&")

        var codePart: String?

        for queryPart in queryParts where queryPart.hasPrefix("code=") {
            let codeStartIndex = queryPart.index(queryPart.startIndex, offsetBy: 5)
            codePart = String(queryPart[codeStartIndex...])
        }

        let codeFound = try XCTUnwrap(codePart)

        // Get Token

        let tokenResponse = try await app.sendRequest(.POST, "/oauth/token/") { request async throws in
            try request.content.encode([
                "grant_type": "authorization_code",
                "client_id": clientID,
                "client_secret": clientSecret,
                "redirect_uri": redirectURI,
                "code": codeFound,
                "scope": scope
            ])
        }

        print("Token response was \(tokenResponse.body.string)")

        let jsonTokenResponse = try XCTUnwrap(JSONSerialization.jsonObject(with: tokenResponse.body) as? [String: Any])
        let token = try XCTUnwrap(jsonTokenResponse["access_token"] as? String)
        let refreshToken = try XCTUnwrap(jsonTokenResponse["refresh_token"] as? String)

        // Get resource

        let protectedResponse = try await app.sendRequest(.GET, "/protected/") { request async throws in
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        XCTAssertEqual(protectedResponse.status, .ok)

        // Get new token

        let tokenRefreshResponse = try await app.sendRequest(.POST, "/oauth/token/") { request async throws in
            try request.content.encode([
                "grant_type": "refresh_token",
                "client_id": clientID,
                "client_secret": clientSecret,
                "scope": scope,
                "refresh_token": refreshToken
            ])
        }

        let jsonTokenRefreshResponse = try XCTUnwrap(JSONSerialization.jsonObject(with: tokenRefreshResponse.body) as? [String: Any])
        let newAccessToken = try XCTUnwrap(jsonTokenRefreshResponse["access_token"] as? String)

        XCTAssertEqual(tokenRefreshResponse.status, .ok)

        // Check user returned

        let userResponse = try await app.sendRequest(.GET, "/user") { request async throws in
            request.headers.add(name: "Authorization", value: "Bearer \(newAccessToken)")
        }

        let decodedUserResponse = try userResponse.content.decode([String: String].self)

        XCTAssertEqual(userResponse.status, .ok)
        XCTAssertEqual(decodedUserResponse["userID"], user.id)
        XCTAssertEqual(decodedUserResponse["username"], username)
        XCTAssertEqual(decodedUserResponse["email"], email)
    }

    func testThatPasswordCredentialsWorksAsExpectedWithFluentModel() async throws {
        let tokenResponse = try await app.sendRequest(.POST, "/oauth/token/") { request async throws in
            try request.content.encode([
                "grant_type": "password",
                "client_id": passwordClientID,
                "client_secret": clientSecret,
                "scope": scope,
                "username": username,
                "password": password
            ])
        }

        print("Token response was \(tokenResponse.body.string)")

        let jsonTokenResponse = try XCTUnwrap(JSONSerialization.jsonObject(with: tokenResponse.body) as? [String: Any])
        let token = try XCTUnwrap(jsonTokenResponse["access_token"] as? String)

        // Get resource

        let protectedResponse = try await app.sendRequest(.GET, "/protected/") { request async throws in
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        XCTAssertEqual(protectedResponse.status, .ok)

        // Check user returned

        let userResponse = try await app.sendRequest(.GET, "/user") { request async throws in
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        let decodedUserResponse = try userResponse.content.decode([String: String].self)

        XCTAssertEqual(userResponse.status, .ok)
        XCTAssertEqual(decodedUserResponse["userID"], user.id)
        XCTAssertEqual(decodedUserResponse["username"], username)
        XCTAssertEqual(decodedUserResponse["email"], email)
    }

    func testThatRemoteTokenIntrospectWorksAsExpectedWithFluentModel() async throws {
        let tokenString = "ABCDEFGH"
        let expiryDate = Date().addingTimeInterval(3600)
        let token = FluentAccessToken(tokenString: tokenString, clientID: clientID, userID: user.id,
                                      expiryTime: expiryDate, scopes: [scope])
        try await token.save(on: app.db)

        let credentials = "\(username):\(password)".base64String()
        let authHeader = "Basic \(credentials)"

        let response = try await app.sendRequest(.POST, "/oauth/token_info") { request async throws in
            request.headers.add(name: "Authorization", value: authHeader)
            try request.content.encode(["token": tokenString])
        }

        XCTAssertEqual(response.status, .ok)

        let responseJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: response.body) as? [String: Any])

        XCTAssertEqual(responseJSON["active"] as? Bool, true)
        XCTAssertEqual(responseJSON["exp"] as? Int, Int(expiryDate.timeIntervalSince1970))
        XCTAssertEqual(responseJSON["username"] as? String, username)
        XCTAssertEqual(responseJSON["client_id"] as? String, clientID)
        XCTAssertEqual(responseJSON["scope"] as? String, scope)

        let wrongCredentials = "unknown:\(password)".base64Bytes()
        let wrongAuthHeader = "Basic \(wrongCredentials)"

        let failingResponse = try await app.sendRequest(.POST, "/oauth/token_info") { request async throws in
            request.headers.add(name: "Authorization", value: wrongAuthHeader)
        }

        XCTAssertEqual(failingResponse.status, .unauthorized)
    }
}

class CapturingAuthHandler: AuthorizeHandler {

    private(set) var request: Request?
    private(set) var responseType: String?
    private(set) var clientID: String?
    private(set) var redirectURI: URI?
    private(set) var scope: [String]?
    private(set) var state: String?
    private(set) var csrfToken: String?

    var authenticateRequestWithUser: OAuthUser?

    func handleAuthorizationRequest(
        _ request: Vapor.Request,
        authorizationRequestObject: VaporOAuth.AuthorizationRequestObject
    ) async throws -> Vapor.Response {
        self.request = request
        self.responseType = authorizationRequestObject.responseType
        self.clientID = authorizationRequestObject.clientID
        self.redirectURI = authorizationRequestObject.redirectURI
        self.scope = authorizationRequestObject.scope
        self.state = authorizationRequestObject.state
        self.csrfToken = authorizationRequestObject.csrfToken

        if !request.auth.has(OAuthUser.self),
           let user = authenticateRequestWithUser {
            request.auth.login(user)
        }

        return Response(status: .ok)
    }

    func handleAuthorizationError(_ errorType: VaporOAuth.AuthorizationError) async throws -> Vapor.Response {
        return Response(status: .internalServerError)
    }
}

struct TestResourceController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let oauthMiddleware = OAuth2ScopeMiddleware(requiredScopes: ["email"])
        let protected = routes.grouped(oauthMiddleware)

        protected.get("protected", use: protectedHandler)
        protected.get("user", use: getOAuthUser)
    }

    private func protectedHandler(request: Request) throws -> some ResponseEncodable {
        return "PROTECTED"
    }

    private func getOAuthUser(request: Request) async throws -> some AsyncResponseEncodable {
        let user = try await request.oAuthHelper.user(request)

        var json: [String: String] = [:]
        json["userID"] = user.id
        json["email"] = user.emailAddress
        json["username"] = user.username

        return json
    }
}

struct UserSessionAuthenticator: AsyncSessionAuthenticator {

    typealias User = OAuthUser

    func authenticate(sessionID: String, for request: Request) async throws {
        guard let user = try await FluentOAuthUser.find(sessionID, on: request.db) else {
            return
        }
        request.auth.login(user.oAuthUser)
    }
}
