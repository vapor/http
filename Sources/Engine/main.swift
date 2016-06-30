let c = try HTTPClient<FoundationStream>.get("https://api.spotify.com/v1/search?q=beyonce&type=album", headers: ["Accept": "application/json"])
print("RESP: \(c.json)")
