# Engine

The core transport layer used in [Vapor](https://github.com/qutheory/github)

## 🚦 Current Environment

| Engine | Xcode | Swift |
|:-:|:-:|:-:|
|0.1.x|8.0 Beta|DEVELOPMENT-SNAPSHOT-2016-06-20-a|

<h3 align="center">❗️<b>WARNING</b>❗️</h3>

<b>Only applies to versions <= 0.12.x</b>

If you've installed Xcode 8, you'll likely get an SDK error when building from command line. The following command has been known to help:

```
sudo xcode-select -s /Applications/Xcode.app/
```

## Linux Ready

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

## Quick Start

#### HTTPClient

```Swift
import Engine

let response = try HTTPClient<TCPClientStream>.get("http://pokeapi.co/api/v2/pokemon/")
print(response)
```

#### HTTPServer

```Swift
import Engine

final class Responder: HTTPResponder {
    func respond(to request: Request) throws -> Response {
        print(request)
        let body = "Hello World".makeBody()
        return Response(body: body)
    }
}

let server = try HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>(port: port)

print("visit http://localhost:\(port)/")
try server.start(responder: Responder()) { error in
    print("Got error: \(error)")
}
```

#### WebSockets

```Swift
import Engine

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

## Architecture

#### HTTPServer

The HTTPServer is responsible for listening and accepting remote connections, then relaying requests and responses between the received connection and the responder.

![](/Resources/Diagrams/HTTPServerDiagram.png)

#### HTTPClient

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

Our homepage [http://qutheory.io](http://qutheory.io) is currently running using Vapor on DigitalOcean.

## 👥 Authors

Made by [Tanner Nelson](https://twitter.com/tanner0101), [Logan Wright](https://twitter.com/logmaestro), and the hundreds of members of the Qutheory community.
