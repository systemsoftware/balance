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
    private var currentTitle: String = "" { didSet { currentTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var currentLink: String = "" { didSet { currentLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var currentDescription: String = "" { didSet { currentDescription = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines) } }
    private var currentPubDate: String = "" { didSet { currentPubDate = currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines) } }
    
    // Track whether the parser is inside an <item> block
    private var isInsideItem = false
    
    func parseFeed(from url: URL) async -> [RSSItem] {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        // This blocks the thread synchronously during execution, 
        // which is why it runs inside an async context.
        parser.parse() 
        
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
                title: currentTitle,
                link: currentLink,
                description: currentDescription,
                pubDate: currentPubDate
            )
            rssItems.append(item)
            isInsideItem = false
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parsing error encountered: \(parseError.localizedDescription)")
    }
}
