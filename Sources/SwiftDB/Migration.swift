//
//  Migration.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 6/21/25.
//
public protocol Migration: Sendable {
    static var name: String { get }
    static func up(on db: Database) async throws
    static func down(on db: Database) async throws
}

