import Foundation

// Public extension so that this can be used anywhere to easily perform operations on the URI query
//    ie: The LoginRedirectMiddleware and adding the cameFrom key/value to the URI
public extension URI {
    /** 
     Adds a new query to the uri with the specified key/value

     - Parameters:
     - key: The query key
     - value: The query value
     */
    mutating func addQuery(withKey key: String, value: String? = nil) {
        var newQuery: String = key
        // Escape the value and add it to the newQuery
        if let value = value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            newQuery += "=\(value)"
        }
        // Get the existing query
        guard var q = query else {
            query = newQuery
            return
        }
        // If there are already keys/values in the query, append an ampersand and then the new query
        if (q.characters.count > 0) {
            q += "&\(newQuery)"
            query = q
        // Otherwise, go ahead and make the query the new query
        } else {
            query = newQuery
        }
    }

    /**
     Removes the specified query key from the URI, if it exists
     
     - Parameter key: The key to remove
     */
    mutating func removeQuery(forKey key: String) {
        // Get the query, return if no query (since there's no keys anyways)
        guard let q = query else {
            return
        }
        var queryString = ""
        // Iterate over the queries
        for _query in q.components(separatedBy: "&") {
            // Split the query into key/value
            let components = _query.components(separatedBy: "=")
            // Continue if there is no key for some reason (There should ALWAYS be a key, so I doubt this will ever happen)
            guard let queryKey = components.first else {
                continue
            }
            // If the queryKey isn't the one to remove, add the query into the queryString
            if (queryKey != key) {
                queryString += "\(_query)&"
            }
        }
        // If the last character is an ampersand, remove it
        let lastChar = queryString.substring(from: queryString.index(before: queryString.endIndex))
        if (lastChar == "&") {
            queryString = queryString.substring(to: queryString.index(before: queryString.endIndex))
        }
        // Set the query
        self.query = queryString
    }

    /**
     Returns the value of the query with the specified key, or "true" if the key is a flag type query
     
     - Parameter key: The key to get the value of
     
     - Returns: A string equal to the query value, "true" if it's a flag with no set value, or nil if it doesn't exist
     */
    func getQueryValue(forKey key: String) -> String? {
        // Get the query, return if no query (since there's no keys anyways)
        guard let q = query else {
            return nil
        }
        // Iterate over the queries
        for _query in q.components(separatedBy: "&") {
            // Split the query into key/value
            let components = _query.components(separatedBy: "=")
            // Continue if there is no key for some reason (There should ALWAYS be a key, so I doubt this will ever happen)
            guard let queryKey = components.first else {
                continue
            }
            // If we have a query with specified key
            if (queryKey == key) {
                // If the query is just a flag (a key with no value), return "true"
                guard let value = components.last, value != queryKey else {
                    return "true"
                }
                // Otherwise, remove any percent encoding and return it
                return value.removingPercentEncoding
            }
        }
        // Return nil if we didn't find a query with the specified key
        return nil
    }
}

