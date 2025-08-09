<picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/e7116ced-1da1-4f78-9974-1700fb5f9d89">
   <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/5a70deeb-b8dc-4708-85d2-8716522d1d15">
   <img alt="Logo" src="./READMEImages/SwiftWebLogo.png"  width="400">
</picture>



> The developer experience of Rails with the type safety and speed of Swift.

SwiftWeb is a HTTP web framework for Swift. It aims to replicate the rapid development and ergonomics of Ruby on Rails while being extremely performant and type safe. To achieve this, SwiftWeb leverages Swift's modern concurrency system to handle web requests with exceptional efficiency and safety.

-----

## Getting Started

1. Install SwiftWeb in your terminal if you haven't yet:
   
   ```bash
   $ swift package install --url todo.com
   ```

2. In the terminal, create a new SwiftWeb application:
   
   ```bash
   $ swiftweb new myapp
   ```

   where "myapp" is the application name.

3. Change directory to `myapp` and start the web server:
   
   ```bash
   $ cd myapp
   $ swift run myapp server
   ```

4. Go to `http://localhost:8080` and you'll see the SwiftWeb welcome screen.

   <img width="400" alt="screely-1754769597841" src="https://github.com/user-attachments/assets/4042ade3-203d-4b94-a17d-f3379ff4e5d0" />


## 🎯 Showcase

Similar to Rails, SwiftWeb includes everything needed to create performant databased-backed web applications according to the[Model-View-Controller (MVC)](https://en.wikipedia.org/wiki/Model-view-controller) pattern.

### Models

To define a model, simply create a Swift struct that conforms to the `Model` protocol: 

```swift
struct Book: Model {
    static let schema: String = "books"

    var id: Int?
    var title: String
    var author: String
}
```

To migrate the model to the database, create a migration file. SwiftWeb will automatically generate the up and down methods.

```swift
struct CreateBooks: Migration {
    static let name: String = "20250719121932_CreateBooks"

    static func change(builder: SchemaBuilder) {
        builder.createTable("books") { t in
            t.column("title", type: "text")
            t.column("author", type: "text")
        }
    }
}
```

To run the migration, run the following command in your terminal:
```bash
$ swift run myapp db migrate
```

### Views

SwiftWeb views are HTML with embedded Swift code:

```html
<h1>Books</h1>
<ul>
    <% for book in books { %>
        <li><a href="/books/<%= book.id %>"><%= book.title %></a></li>
    <% } %>
</ul>
<a href="/books/new">New Book</a>
```

### Controllers

Controllers are a collection of handlers that are responsible for processing incoming HTTP requests and providing a suitable response.

```swift
struct BooksController {
    func index(req: Request) async throws -> Response { 
        let books = try await Book.all(on: req.app.db)
        return try .view("index", models: books, on: req)
    }

    func show(req: Request) async throws -> Response { 
        let id = try req.get(param: "id", as: Int.self)
        let book = try await Book.find(id: id, on: req.app.db)
        return try .view("show", with: book, on: req)
    }

    func new(req: Request) async throws -> Response { 
        return try .view("new", on: req)
    }

    func edit(req: Request) async throws -> Response { 
        let id = try req.get(param: "id", as: Int.self)
        let book = try await Book.find(id: id, on: req.app.db)
        return try .view("edit", with: book, on: req)
    }

    func create(req: Request) async throws -> Response { 
        var book = try req.get(Book.self, encoding: .form)
        try await book.save(on: req.app.db)
        let id = try book.getId()
        return .redirect(to: "/books/\(id)")
    }

    func update(req: Request) async throws -> Response { 
        let id = try req.get(param: "id", as: Int.self)
        let book = try req.get(Book.self, encoding: .form)
        try await book.update(id: id, on: req.app.db)
        return .redirect(to: "/books/\(id)")
    }

    func destroy(req: Request) async throws -> Response { 
        let id = try req.get(param: "id", as: Int.self)
        try await Book.destroy(id: id, on: req.app.db)
        return .redirect(to: "/books")
    }
}
```

### Router

To connect your controller actions to routes, simply register them in `routes.swift`. 

```swift
func routes() -> Router {
    let router = RouterBuilder()
    
    router.get("/", to: HelloController().hello)

    router.resources("/books", for: BooksController.self)
    
    return router.build()
}
```

## 🚀 Performance

Tested on 12 core Apple M2 Pro with 16 GB of memory against Vapor and Ruby on Rails.

### Happy Path

### Database Fetch


## 🤝 Contributing

We welcome contributions of all kinds! Whether you're a seasoned developer or just getting started with Swift, we'd love to have your help.

If you find a bug, have a feature request, or would like to contribute code, please open an [issue](https://github.com/nikodittmar/SwiftWeb/issues) or submit a [pull request](https://github.com/nikodittmar/SwiftWeb/pulls).

## 📜 License

SwiftWeb is open source and available under the **MIT License**. You can view the full license in the `LICENSE.md` file.
