<p align="center">
    <img src="https://user-images.githubusercontent.com/9938337/29741382-4aeaa670-8a63-11e7-8330-583ce2858fdc.png" alt="Vapor OAuth Fluent">
</p>
<h1 align="center">Vapor OAuth Fluent</h1>
<p align="center">
    <a href="https://swift.org">
        <img src="https://img.shields.io/badge/swift-5.6-brightgreen.svg" alt="Language">
    </a>
    <a href="https://travis-ci.org/brokenhandsio/vapor-oauth-fluent">
        <img src="https://travis-ci.org/brokenhandsio/vapor-oauth-fluent.svg?branch=master" alt="Build Status">
    </a>
    <a href="https://codecov.io/gh/brokenhandsio/vapor-oauth-fluent">
        <img src="https://codecov.io/gh/brokenhandsio/vapor-oauth-fluent/branch/master/graph/badge.svg" alt="Code Coverage">
    </a>
    <a href="https://raw.githubusercontent.com/brokenhandsio/vapor-oauth-fluent/master/LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
    </a>
</p>


This repo contains a Fluent implementations for the required protocols for [Vapor OAuth](https://github.com/brokenhandsio/vapor-oauth).

# Usage

Vapor OAuth can Fluent be added to your Vapor add with a simple provider. To get started, first add the library to your `Package.swift` dependencies:

```swift
dependencies: [
    ...,
    .package(url: "https://github.com/brokenhandsio/vapor-oauth-fluent", .upToNextMajor(from: "1.0.0"))
]
```

Next import the library into where you set up your `Application`:

```swift
import VaporOAuthFluent
```

Then choose the implementations you wish to add to the `VaporOAuth.OAuth2` service. For example:

```swift
let userManager = FluentUserManager(passwordHasher: app.password, database: app.db)
let tokenManager = FluentTokenManager(database: app.db)
app.lifecycle.use(VaporOAuth.OAuth2(
    codeManager: FluentCodeManager(database: app.db),
    tokenManager: tokenManager,
    clientRetriever: FluentClientRetriever(database: app.db),
    authorizeHandler: MyAuthHandler(),
    userManager: userManager,
    validScopes: [scope],
    resourceServerRetriever: FluentResourceServerRetriever(database: app.db),
    oAuthHelper: .local(
        tokenAuthenticator: TokenAuthenticator(),
        userManager: userManager,
        tokenManager: tokenManager
    )
))
```

You can choose which implementations to use, or write your custom ones. For instance you may choose to use Fluent for Tokens and Users, but hard code the clients and use JWT to manage Codes.

# Models Included

The following models have Fluent extensions included with this repository:

* FluentAccessToken
* FluentRefreshToken
* FluentOAuthCode
* FluentOAuthUser
* FluentOAuthClient
* FluentOAuthResourceServer

**Note** you will need to add these models to your preparations if you wish to use any of these.

# Managers Included

As well as models, Vapor OAuth Fluent includes implementations for the Managers required to interact with the models. The included managers are:

* FluentClientRetriever
* FluentCodeManager
* FluentTokenManager
* FluentUserManager
* FluentResourceServerRetriever
