import Down

extension Node {
    func iterate(_ body: (Node) -> Void) {
        body(self)
        for node in childSequence {
            node.iterate(body)
        }
    }

    func links(relative: Bool = false, includeImage: Bool = false) -> [String] {
        var links: [String] = []
        iterate {
            let url: String?
            switch $0 {
            case let link as Image:
                guard includeImage else { return }
                url = link.url
            case let link as Link:
                url = link.url
            default:
                return
            }
            guard let dest = url else { return }
            if relative, dest.contains(":") || dest.contains("//") {
                return
            }
            links.append(dest)
        }
        return links
    }

    func text() -> String {
        var parts: [String] = []
        iterate {
            switch $0 {
            case is SoftBreak:
                parts.append(" ")
            case let text as Text:
                guard let literal = text.literal else { return }
                parts.append(literal)
            case let code as Code:
                guard let literal = code.literal else { return }
                parts.append(literal)
            default:
                return
            }
        }
        return parts.joined()
    }

    func words(upTo: Int) -> String {
        let words = text().split { $0.isWhitespace }
        return words[..<min(words.count, upTo)].joined(separator: " ")
    }

    func name() -> String {
        for node in childSequence {
            guard let header = node as? Heading else { continue }
            let text = header.text()
            if text != "" {
                return text
            }
        }
        for node in childSequence {
            let words = node.words(upTo: 8)
            if words != "" {
                return words
            }
        }
        return ""
    }
}
