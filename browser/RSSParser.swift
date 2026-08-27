import Foundation

struct RSSItem: Hashable {
    var id = UUID()
    var title: String = ""
    var link: String = ""
    var description: String = ""
    var pubDate: String = ""
}


class RSSParser: NSObject, XMLParserDelegate {
    private var rssItems: [RSSItem] = []
    private var currentElement = ""
    
    // Properties to build the currently parsed item
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    
    // Track whether the parser is inside an <item> block
    private var isInsideItem = false
    
    func parseFeed(from url: URL) async -> [RSSItem] {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) ?? true
        else { return [] }

        rssItems.removeAll(keepingCapacity: true)
        isInsideItem = false
        currentElement = ""
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        // This blocks the thread synchronously during execution, 
        // which is why it runs inside an async context.
        guard parser.parse() else { return [] }
        
        return rssItems
    }
    
    // MARK: - XMLParserDelegate Methods
    
    // 1. Triggered when an opening tag is hit (e.g., <item> or <title>)
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            // Reset temp properties for a fresh article entry
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }
    
    // 2. Triggered when characters are found inside tags
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return } // Skip channel-level title/links
        
        switch currentElement {
        case "title":       currentTitle += string
        case "link":        currentLink += string
        case "description": currentDescription += string
        case "pubDate":     currentPubDate += string
        default:            break
        }
    }
    
    // 3. Triggered when a closing tag is hit (e.g., </item>)
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            let item = RSSItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            rssItems.append(item)
            isInsideItem = false
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parsing error encountered: \(parseError.localizedDescription)")
    }
}
