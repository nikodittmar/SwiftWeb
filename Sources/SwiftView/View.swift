//
//  View.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/30/25.
//
import Foundation

/// A view renderer that loads, parses, and renders `.swift.html` templates.
///
/// The ``View`` class is the core of the templating system. Create an instance of this class at startup,
/// pointing it to your project's "Views" directory. It will automatically discover and prepare
/// your templates for rendering.
///
/// ### Usage
///
/// First, initialize the ``View`` object with the path to your templates directory:
///
/// ```swift
/// let viewsDirectory = URL(fileURLWithPath: "path/to/your/Views")
/// let viewRenderer = View(viewsDirectory: viewsDirectory)
/// ```
///
/// Then, use the ``render(_:with:)`` method to generate HTML from a template by providing
/// a template name and a data context.
///
/// ```swift
/// struct User: Encodable {
///     let name: String
/// }
///
/// let html = try viewRenderer.render("users/profile", with: User(name: "Niko"))
/// print(html)
/// ```
public final class Views: Sendable {
    private let views: [String: [ASTNode]]
    
    /// Initializes the view renderer by discovering and preparing all `.swift.html`
    /// templates within a given directory.
    ///
    /// - Parameter viewsDirectory: The ``URL`` of the directory containing your template files.
    public init(viewsDirectory: URL) {
        var loadedViews: [String: [ASTNode]] = [:]
        
        guard let contents = FileManager.default.enumerator(
            at: viewsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            fatalError("[SwiftView] ❌ Failed to load the contents of the views directory.")
        }
        
        for case let url as URL in contents {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
                
                guard resourceValues.isRegularFile == true, url.path.hasSuffix(".swift.html") else { continue }
                
                let relativePath = url.path.replacingOccurrences(of: viewsDirectory.path, with: "")
                
                // Remove leading "/" and ".swift.html" (11 characters)
                let viewName = String(relativePath.dropFirst().dropLast(11))
                
                let content = try String(contentsOf: url, encoding: .utf8)
                
                let tokens = try Tokenizer.tokenize(content)
                
                let syntaxTree = try Parser.parse(tokens)
                
                loadedViews[viewName] = syntaxTree
            } catch {
                fatalError("[SwiftView] ❌ Failed to load or parse view at \(url.path): \(error)")
            }
        }
        
        self.views = loadedViews
    }
    
    /// Renders a template with a given context.
    ///
    /// - Parameters:
    ///   - name: The name of the template to render. For a file located at
    ///     `Views/users/profile.swift.html`, the name would be `"users/profile"`.
    ///   - context: An ``Encodable`` object whose properties will be available inside the template.
    /// - Throws: A ``ViewStoreError/viewNotFound(name:)`` if the template name doesn't exist.
    /// - Returns: An HTML ``String`` with the template's content and data merged.
    public func render<T: Encodable>(_ name: String, with context: T, layout: Layout? = nil) throws -> String {
        guard let syntaxTree = views[name] else { throw ViewStoreError.viewNotFound(name: name) }

        let view = try Evaluator.evaluate(syntaxTree: syntaxTree, context: context)

        if let layout = layout { 
            return try layout.render(loadedViews: views, yield: view) 
        } else {
            return view
        }
    }

    /// Renders a view.
    ///
    /// - Parameters:
    ///   - name: The name of the template to render. For a file located at
    ///     `Views/users/profile.swift.html`, the name would be `"users/profile"`.
    /// - Throws: A ``ViewStoreError/viewNotFound(name:)`` if the template name doesn't exist.
    /// - Returns: An HTML ``String`` with the template's content and data merged.
    public func render(_ name: String, layout: Layout? = nil) throws -> String {
        guard let syntaxTree = views[name] else { throw ViewStoreError.viewNotFound(name: name) }

        let view = try Evaluator.evaluate(syntaxTree: syntaxTree)

        if let layout = layout { 
            return try layout.render(loadedViews: views, yield: view) 
        } else {
            return view
        }
    }

    private struct LayoutContext: Encodable {
        let yield: String
    }
}

/// An error that can occur during the view rendering process.
public enum ViewStoreError: Error, LocalizedError {
    /// Thrown when a template with the specified name cannot be found.
    case viewNotFound(name: String)
    
    public var errorDescription: String? {
        switch self {
        case .viewNotFound(let name):
            return "The view named '\(name)' could not be found."
        }
    }
}
