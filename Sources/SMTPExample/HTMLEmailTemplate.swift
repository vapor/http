import SMTP

func multicolorHTML(pairs: [String: String]) -> EmailBody {
    var html = ""
    html += "<!DOCTYPE html>"
    html += "<html>"
    html += "<body style=\"background-color:black;\">"

    html += "<h1 align=\"center\">"
    for (text, color) in pairs {
        html += "<b style=\"color:\(color)\">\(text)</b>"
    }
    html += "</h1>"
    
    html += "</body>"
    html += "</html>"
    return EmailBody(type: .html, content: html)
}
