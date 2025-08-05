//
//  Database.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/5/25.
//
import Foundation

public protocol Cache: Sendable {
    func get<T: Model>(_ key: String) async throws -> T?
    func set<T: Model>(_ key: String, to value: T) async throws
    func delete(_ key: String) async throws
}