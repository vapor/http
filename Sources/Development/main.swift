import Engine
import WebSockets


let response = try HTTPClient<TCPClientStream>.get("https://api.spotify.com/v1/search?q=beyonce&type=artist")
print(response.body.bytes?.string)


try WebSocket.connect(to: "ws://vapor-dashboard.herokuapp.com/updates") { ws in
    print("connected")

    ws.onText = { ws, text in
        print("[ws] - \(text)")
    }

    ws.onClose = { _ in
        print("CLOSED")
    }
}

print("done")
