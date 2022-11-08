import Markdown
import Paths

// TODO: Dedupe with Engine.NoteWalker?
struct NoteWalker: MarkupWalker {
    var from: File.Name
    var context = ""
    var fallback = ""
    var header = ""

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
