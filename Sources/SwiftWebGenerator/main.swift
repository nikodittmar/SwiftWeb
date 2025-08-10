//
//  main.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
import ArgumentParser

struct SwiftWebGenerator: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftweb",
        abstract: "A command-line tool to generate a new SwiftWeb project.",
        subcommands: [New.self],
        defaultSubcommand: New.self
    )
}

extension SwiftWebGenerator {
    struct New: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "new",
            abstract: "Creates a new SwiftWeb project from a template."
        )

        @Argument(help: "The name of the new project to generate.")
        var projectName: String

        func run() throws {
            let generator = ProjectGenerator(projectName: projectName)
            try generator.generate()
        }
    }
}

SwiftWebGenerator.main()
