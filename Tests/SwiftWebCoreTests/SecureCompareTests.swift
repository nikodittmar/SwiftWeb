import Testing
import SwiftWebCore

@Suite("Secure Compare Tests")
struct SecureCompareTests {

    @Test("Equal strings should return true")
    func testEqualStrings() {
        let stringA = "my_secret_password_hash_123"
        let stringB = "my_secret_password_hash_123"
        #expect(SwiftWebUtils.secureCompare(a: stringA, b: stringB) == true)
    }

    @Test("Different strings of the same length should return false")
    func testDifferentStringsSameLength() {
        let stringA = "my_secret_password_hash_123"
        let stringB = "my_secret_password_hash_456" // Different ending
        #expect(SwiftWebUtils.secureCompare(a: stringA, b: stringB) == false)
    }

    @Test("Strings of different lengths should return false")
    func testDifferentLengths() {
        let stringA = "short"
        let stringB = "much_longer_string"
        #expect(SwiftWebUtils.secureCompare(a: stringA, b: stringB) == false)
    }
    
    @Test("Comparing a string to an empty string should return false")
    func testOneEmptyString() {
        let stringA = "not_empty"
        let stringB = ""
        #expect(SwiftWebUtils.secureCompare(a: stringA, b: stringB) == false)
    }

    @Test("Comparing two empty strings should return true")
    func testBothEmptyStrings() {
        let stringA = ""
        let stringB = ""
        #expect(SwiftWebUtils.secureCompare(a: stringA, b: stringB) == true)
    }
    
    @Test("Strings with different character cases should return false")
    func testDifferentCase() {
        let stringA = "Password123"
        let stringB = "password123"
        #expect(SwiftWebUtils.secureCompare(a: stringA, b: stringB) == false)
    }
}