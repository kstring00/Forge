import UIKit
import ForgeCore

/// Decision 0041: the plan on paper. LaunchPlanDocument writes the page as
/// HTML (tested in ForgeCore); this lays it out on US Letter pages with
/// UIKit's print renderer, which paginates, and saves a PDF to share.
enum PlanPDF {
    @MainActor
    static func write(_ input: LaunchPlanDocument.Input) throws -> URL {
        let formatter = UIMarkupTextPrintFormatter(markupText: LaunchPlanDocument.html(input))
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let paper = CGRect(x: 0, y: 0, width: 612, height: 792)
        renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: paper.insetBy(dx: 54, dy: 54)), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paper, [kCGPDFContextTitle as String: "\(input.title): launch plan"])
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        let name = input.title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name.isEmpty ? "Idea" : name) launch plan.pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
}
