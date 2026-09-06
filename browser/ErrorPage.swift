import Foundation

enum ErrorPageBuilder {

    static let retryScheme = "balance-error-retry"

    static func classify(_ error: NSError) -> BrowserErrorKind? {
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return nil
        }
  
        // WebKitErrorDomain "frame load interrupted" (102) also happens for legitimate
        // things like downloads and plugin handoffs — ignore it too.
        if error.domain == "WebKitErrorDomain" && error.code == 102 {
            return nil
        }

        guard error.domain == NSURLErrorDomain else {
            return .generic(error.localizedDescription)
        }

        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .offline
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .cannotFindHost
        case NSURLErrorCannotConnectToHost:
            return .cannotConnect
        case NSURLErrorTimedOut:
            return .timedOut
        case NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorClientCertificateRejected:
            return .sslError
        default:
            return .generic(error.localizedDescription)
        }
    }

    static func html(for kind: BrowserErrorKind, url: URL?) -> String {
            let host = url?.host ?? url?.absoluteString ?? "this site"
            let title: String
            let message: String
            let icon: String

            switch kind {
            case .offline:
                title = "No Internet Connection"
                message = "Check your connection and try again."
                icon = Self.iconOffline
            case .cannotFindHost:
                title = "Can't Find Server"
                message = "Balance can't find the server at \(escape(host))."
                icon = Self.iconWarning
            case .cannotConnect:
                title = "Can't Connect to Server"
                message = "The server at \(escape(host)) may be temporarily down."
                icon = Self.iconWarning
            case .timedOut:
                title = "Request Timed Out"
                message = "The connection to \(escape(host)) timed out."
                icon = Self.iconWarning
            case .sslError:
                title = "Connection Not Private"
                message = "Balance can't verify the identity of \(escape(host))."
                icon = Self.iconLock
            case .generic(let msg):
                title = "Something Went Wrong"
                message = escape(msg)
                icon = Self.iconWarning
            }

            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escape(title))</title>
            <style>
            :root { color-scheme: light dark; }
            * { box-sizing: border-box; }
            html, body {
                margin: 0; height: 100%;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                background: Canvas; color: CanvasText;
            }
            body { display: flex; align-items: center; justify-content: center; padding: 24px; }
            .wrap { max-width: 360px; }
            .icon { width: 30px; height: 30px; margin-bottom: 16px; opacity: 0.5; }
            .icon svg { width: 100%; height: 100%; }
            h1 { font-size: 17px; font-weight: 600; margin: 0 0 6px; letter-spacing: -0.2px; }
            p { font-size: 13px; opacity: 0.55; line-height: 1.45; margin: 0 0 20px; }
            button {
                font: inherit; font-size: 13px; font-weight: 500; padding: 7px 16px;
                border-radius: 6px; border: 1px solid; border-color: color-mix(in srgb, CanvasText 15%, transparent);
                background: transparent; color: CanvasText; cursor: pointer;
            }
            button:hover { background: color-mix(in srgb, CanvasText 6%, transparent); }
            button:active { background: color-mix(in srgb, CanvasText 12%, transparent); }
            .url { font-size: 11px; opacity: 0.35; margin-top: 16px; word-break: break-all; }
            </style>
            </head>
            <body>
            <div class="wrap">
                <div class="icon">\(icon)</div>
                <h1>\(escape(title))</h1>
                <p>\(message)</p>
                <button onclick="location.href='\(retryScheme)://retry'">Try Again</button>
                \(url.map { "<div class=\"url\">\(escape($0.absoluteString))</div>" } ?? "")
            </div>
            </body>
            </html>
            """
        }

        private static let iconWarning = """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 9v4M12 16.5h.01M10.3 3.9 2.6 17.5a1.8 1.8 0 0 0 1.56 2.7h15.7a1.8 1.8 0 0 0 1.56-2.7L13.7 3.9a1.8 1.8 0 0 0-3.14 0Z" stroke-linecap="round" stroke-linejoin="round"/></svg>
        """

        private static let iconOffline = """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 8.5C7 4 17 4 22 8.5M5.5 12c3.5-3 9.5-3 13 0M9 15.5c1.7-1.3 4.3-1.3 6 0" stroke-linecap="round"/><circle cx="12" cy="19" r="1"/></svg>
        """

        private static let iconLock = """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3" stroke-linecap="round"/></svg>
        """


    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
