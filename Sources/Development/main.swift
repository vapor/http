import Vapor

let response = try HTTPClient<TCPClientStream>.get("https://api.spotify.com/v1/search?q=beyonce&type=artist")
print(response.body.bytes?.string)
