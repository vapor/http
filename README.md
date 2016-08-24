# Engine

![Swift](http://img.shields.io/badge/swift-v3.0--dev.08.23-brightgreen.svg)
[![Build Status](https://travis-ci.org/vapor/engine.svg?branch=master)](https://travis-ci.org/vapor/engine)
[![CircleCI](https://circleci.com/gh/vapor/engine.svg?style=shield)](https://circleci.com/gh/vapor/engine)
[![Code Coverage](https://codecov.io/gh/vapor/engine/branch/master/graph/badge.svg)](https://codecov.io/gh/vapor/engine)
[![Codebeat](https://codebeat.co/badges/a793ad97-47e3-40d9-82cf-2aafc516ef4e)](https://codebeat.co/projects/github-com-vapor-engine)
[![Slack Status](http://vapor.team/badge.svg)](http://vapor.team)

Engine is a collection of low level transport protocols implemented in pure Swift intended for use in server side and client side applications. It is used as the core transport layer in [Vapor](https://github.com/qutheory/github).

##### [Engine](#httpclient)
HTTP and Stream layers

##### [WebSockets](#websockets)
Realtime websockets

##### [SMTP](#smtp-1)
Send emails.

## 🌏 Current Environment

|Engine|Xcode|Swift|
|:-:|:-:|:-:|
|0.6.x|8.0 Beta **6**|DEVELOPMENT-SNAPSHOT-2016-08-23-a|
|0.5.x|8.0 Beta **3**|DEVELOPMENT-SNAPSHOT-2016-07-25-a|
|0.4.x|8.0 Beta **3**|DEVELOPMENT-SNAPSHOT-2016-07-25-a|
|0.3.x|8.0 Beta **3**|DEVELOPMENT-SNAPSHOT-2016-07-25-a|
|0.2.x|8.0 Beta **3**|DEVELOPMENT-SNAPSHOT-2016-07-20-qutheory|
|0.1.x|8.0 Beta **2**|3.0-PREVIEW-2|

You can run the following script to verify your environment is correct.

```sh
curl -sL check.qutheory.io | bash
```

## Linux Ready

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

## Quick Start

#### HTTP.Client

```Swift
import HTTP

let response = try Client<TCPClientStream>.get("http://pokeapi.co/api/v2/pokemon/")
print(response)
```

#### HTTP.Server

```Swift
import HTTP

final class MyResponder: Responder {
    func respond(to request: Request) throws -> Response {
        let body = "Hello World".makeBody()
        return Response(body: body)
    }
}

let server = try Server<TCPServerStream, Parser<Request>, Serializer<Response>>(port: port)

print("visit http://localhost:\(port)/")
try server.start(responder: MyResponder()) { error in
    print("Got error: \(error)")
}
```

#### WebSocket Client

```Swift
import Engine
import WebSockets

try WebSocket.connect(to: url) { ws in
    print("Connected to \(url)")

    ws.onText = { ws, text in
        print("[event] - \(text)")
    }

    ws.onClose = { ws, _, _, _ in
        print("\n[CLOSED]\n")
    }
}
```

#### WebSocket Server

```Swift
import HTTP
import WebSockets

final class MyResponder: Responder {
    func respond(to request: Request) throws -> Response {
        return try request.upgradeToWebSocket { ws in
            print("[ws connected]")

            ws.onText = { ws, text in
                print("[ws text] \(text)")
                try ws.send("🎙 \(text)")
            }

            ws.onClose = { _, code, reason, clean in
                print("[ws close] \(clean ? "clean" : "dirty") \(code?.description ?? "") \(reason ?? "")")
            }
        }
    }
}

let server = try Server<TCPServerStream, Parser<Request>, Serializer<Response>>(port: port)

print("Connect websocket to http://localhost:\(port)/")
try server.start(responder: MyResponder()) { error in
    print("Got server error: \(error)")
}
```

#### SMTP

```Swift
import SMTP

let credentials = SMTPCredentials(
    user: "server-admin-login",
    pass: "secret-server-password"
)

let from = EmailAddress(name: "Password Reset",
                        address: "noreply@myapp.com")
let to = "some-user@random.com"
let email: Email = Email(from: from,
                         to: to,
                         subject: "Vapor SMTP - Simple",
                         body: "Hello from Vapor SMTP 👋")

let client = try SMTPClient<TCPClientStream>.makeGmailClient()
try client.send(email, using: credentials)
```

## Architecture

#### HTTP.Server

The HTTPServer is responsible for listening and accepting remote connections, then relaying requests and responses between the received connection and the responder.

![](/Resources/Diagrams/HTTPServerDiagram.png)

#### HTTP.Client

The HTTPClient is responsible for establishing remote connections and relaying requests and responses between the remote connection and the caller.

![](/Resources/Diagrams/HTTPClientDiagram.png)

## 📖 Documentation

Visit official Vapor [Documentation](http://docs.qutheory.io) for extensive information on getting setup, using, and deploying Vapor.

## 💙 Code of Conduct

Our goal is to create a safe and empowering environment for anyone who decides to use or contribute to Vapor. Please help us make the community a better place by abiding to this [Code of Conduct](https://github.com/qutheory/vapor/blob/master/CODE_OF_CONDUCT.md) during your interactions surrounding this project.

## 💡 Evolution

Contributing code isn't the only way to participate in Vapor. Taking a page out of the Swift team's playbook, we want _you_ to participate in the evolution of the Vapor framework. File a GitHub issue on this repository to start a discussion or suggest an awesome idea.

## 💧 Community

We pride ourselves on providing a diverse and welcoming community. Join your fellow Vapor developers in [our slack](slack.qutheory.io) and take part in the conversation.

## 🔧 Compatibility

Vapor has been tested on OS X 10.11, Ubuntu 14.04, and Ubuntu 15.10.

Our homepage [http://vapor.codes](http://vapor.codes) is currently running using Vapor on DigitalOcean.

## 👥 Authors

Made by [Tanner Nelson](https://twitter.com/tanner0101), [Logan Wright](https://twitter.com/logmaestro), and the hundreds of members of the Qutheory community.
