import Markdown

struct NoteWalker: ContextWalker {
    var from: String
    var context = ""
    var fallback = ""
    var header = ""
}

public protocol ContextWalker: MarkupWalker {
    var from: String { get }
    var context: String { get set }
    var fallback: String { get set }
    var header: String { get set }
}

public extension ContextWalker {
    var name: String {
        if header != "" {
            return header
        }
        if fallback != "" {
            return fallback
        }
        return String(from.dropFirst())
    }

    mutating func visitHeading(_ heading: Heading) {
        context = heading.plainText
        defaultVisit(heading)
        guard header == "" else { return }
        header = context
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        context = paragraph.plainText
        defaultVisit(paragraph)
        guard fallback == "" else { return }
        fallback = context
    }
}
