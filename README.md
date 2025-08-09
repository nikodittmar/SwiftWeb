<picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/e7116ced-1da1-4f78-9974-1700fb5f9d89">
   <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/5a70deeb-b8dc-4708-85d2-8716522d1d15">
   <img alt="Logo" src="./READMEImages/SwiftWebLogo.png"  width="400">
</picture>



> The developer experience of Rails with the type safety and speed of Swift.

![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![macOS](https://img.shields.io/badge/macOS-15%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6%2B-orange)

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

Similar to Rails, SwiftWeb includes everything needed to create performant databased-backed web applications according to the [Model-View-Controller (MVC)](https://en.wikipedia.org/wiki/Model-view-controller) pattern.

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

Tested on 12 core Apple M2 Pro with 16 GB of memory.

### Happy Path

```bash
$ wrk -t10 -c130 -d15s http://localhost:8080/hello  
Running 15s test @ http://localhost:8080/hello
  10 threads and 130 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.38ms    4.99ms  77.22ms   90.86%
    Req/Sec    15.23k     1.99k   45.54k    87.56%
  2277978 requests in 15.10s, 410.59MB read
Requests/sec: 150860.34
Transfer/sec:     27.19MB
```

```bash
$ wrk -t1 -c1 -d15s http://localhost:8080/hello 
Running 15s test @ http://localhost:8080/hello
  1 threads and 1 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    36.09us    3.81us 498.00us   95.24%
    Req/Sec    27.11k   801.51    30.13k    97.35%
  407366 requests in 15.10s, 73.43MB read
Requests/sec:  26979.08
Transfer/sec:      4.86MB
```

### Database Fetch

```bash
$ wrk -t10 -c130 -d15s http://localhost:8080/books/1
Running 15s test @ http://localhost:8080/books/1
  10 threads and 130 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.49ms    2.34ms  39.84ms   91.13%
    Req/Sec    14.18k     2.66k   63.11k    83.42%
  2118630 requests in 15.10s, 456.63MB read
Requests/sec: 140310.21
Transfer/sec:     30.24MB
```

```bash
$ wrk -t1 -c1 -d15s http://localhost:8080/books/1
Running 15s test @ http://localhost:8080/books/1
  1 threads and 1 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    39.99us    3.85us 426.00us   94.64%
    Req/Sec    24.52k   693.66    25.57k    96.69%
  368416 requests in 15.10s, 79.40MB read
Requests/sec:  24398.46
Transfer/sec:      5.26MB
```

### Results Comparison

| Database Fetch Single-Threaded Latency  | Database Fetch Single-Threaded Throughput |
| :---: | :---: |
| <img width="300" alt="db_single_thread_latency" src="https://github.com/user-attachments/assets/bef2dec4-eeba-4726-ba49-b89ac22c42af" /> | <img width="300" alt="db_multi_thread_throughput" src="https://github.com/user-attachments/assets/ef61fdcf-d3bd-4149-ba5b-ca277262c321" /> |

| Happy Path Single-Threaded Latency  | Happy Path Multi-Threaded Throughput |
| :---: | :---: |
| <img width="300" alt="happy_single_thread_latency" src="https://github.com/user-attachments/assets/cf854938-79ee-431c-8f2c-431750249f4f" /> | <img width="300" alt="happy_multi_thread_throughput" src="https://github.com/user-attachments/assets/6e808265-2a90-4fe3-ad0b-e059f23b4221" /> |

## 🤝 Contributing

We welcome contributions of all kinds! Whether you're a seasoned developer or just getting started with Swift, we'd love to have your help.

If you find a bug, have a feature request, or would like to contribute code, please open an [issue](https://github.com/nikodittmar/SwiftWeb/issues) or submit a [pull request](https://github.com/nikodittmar/SwiftWeb/pulls).

## 📜 License

SwiftWeb is open source and available under the **MIT License**. You can view the full license in the `LICENSE.md` file.
