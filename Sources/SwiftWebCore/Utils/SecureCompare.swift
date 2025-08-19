//
//  SecureCompare.swift
//  SwiftWeb
//
//  Created by Niko Dittmar on 8/19/25.
//

import Foundation

public extension SwiftWebUtils {
    /// Securely compares two strings in constant time to prevent timing attacks.
    ///
    /// A standard string comparison (`==`) can exit early as soon as a difference is found.
    /// This can leak information about the string's contents based on how long the comparison
    /// takes. This function always compares every byte, ensuring the execution time is
    /// consistent, regardless of whether the strings match or where the first difference occurs.
    ///
    /// - Parameters:
    ///   - a: The first string to compare.
    ///   - b: The second string to compare.
    /// - Returns: `true` if the strings are equal, otherwise `false`.
    static func secureCompare(a: String, b: String) -> Bool {
        // Convert strings to UTF8 byte arrays.
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)

        // Strings of different lengths can't be equal. This length check itself
        // does not leak useful information for most use cases (like comparing hashes).
        guard aBytes.count == bBytes.count else {
            return false
        }

        // Use a variable to accumulate differences. The `|` (bitwise OR) ensures
        // that once a difference is found (result becomes non-zero), it stays non-zero.
        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            // XOR the bytes. The result is 0 if they are the same, non-zero otherwise.
            // Then, OR this with our accumulated result.
            result |= aBytes[i] ^ bBytes[i]
        }

        // The strings are equal if and only if the accumulated result is 0.
        return result == 0
    }
}