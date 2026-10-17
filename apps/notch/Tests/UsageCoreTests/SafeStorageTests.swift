import Foundation
import Testing
@testable import UsageCore

/// The fixture was encrypted outside Swift (Python's hashlib for the key, `openssl enc
/// -aes-128-cbc` with a 16-space IV), so a bug mirrored in encrypt and decrypt can't pass.
@Suite struct SafeStorageTests {
    static let password = Data("fixture-password".utf8)
    static let fixture = "djEwiOmW3mzphYM0a9fB4vHf3065mMJ3OoN3POTQwItZZa6TDJHAhadNmDHqwprQTSkjppycJiaxDvTupp6FAcU/Rndptdke/F8Sr1E4tgR1CKfBraoTnCuxyYuZ2eCSODyL5ynK/lGc78I8+EUGWUQdkR+sdEpZNUMj7/ExPBmaYbjBTGiXxh9HapUxzaXZjw21F9wxlzzoEPsrBpktKNH14nNTPqH7p9yDsqjZmUo33kQs3J8UuT6wZty44w66nuBTpLvAsES5E0IHjsXVCVZ9SqP45PywDx1IiqmzkY56d/ghydR9W6INrCkq81RimWdw"

    @Test func derivesTheChromiumKey() {
        let key = SafeStorage.deriveKey(password: Self.password)
        #expect(key.map { String(format: "%02x", $0) }.joined() == "5d84e88b8d2628e23102b464d77a5bbd")
    }

    @Test func decryptsAnOpenSSLFixture() throws {
        let key = SafeStorage.deriveKey(password: Self.password)
        let plain = try SafeStorage.decrypt(base64: Self.fixture, key: key)
        let json = try #require(try JSONSerialization.jsonObject(with: plain) as? [String: [String: Any]])
        #expect(json.values.first?["token"] as? String == "sk-ant-oat01-fixture")
    }

    @Test func roundTrips() throws {
        let key = SafeStorage.deriveKey(password: Data("other".utf8))
        let text = Data(#"{"a":1}"#.utf8)
        #expect(try SafeStorage.decrypt(base64: SafeStorage.encrypt(text, key: key), key: key) == text)
    }

    @Test func rejectsOtherFormats() {
        let key = SafeStorage.deriveKey(password: Self.password)
        let v11 = (Data("v11".utf8) + Data(repeating: 0, count: 16)).base64EncodedString()
        #expect(throws: UsageError.unknownEncryption) { try SafeStorage.decrypt(base64: v11, key: key) }
        #expect(throws: UsageError.unreadableTokenCache) { try SafeStorage.decrypt(base64: "not base64!", key: key) }
    }

    @Test(arguments: [0, 1, 15, 16, 17, 100])
    func roundTripsEveryPaddingLength(length: Int) throws {
        let key = SafeStorage.deriveKey(password: Self.password)
        let text = Data((0..<length).map { UInt8(truncatingIfNeeded: $0) })
        let blob = try #require(Data(base64Encoded: SafeStorage.encrypt(text, key: key)))
        // PKCS7 always adds padding: a whole block when the text already fills one.
        #expect(blob.count == 3 + (length / 16 + 1) * 16)
        #expect(try SafeStorage.decrypt(base64: blob.base64EncodedString(), key: key) == text)
    }

    @Test func rejectsDamagedCiphertext() throws {
        let key = SafeStorage.deriveKey(password: Self.password)
        let blob = try #require(Data(base64Encoded: Self.fixture))
        for damaged in [Data("v10".utf8), blob.dropLast(1), blob.dropLast(16), blob.prefix(3 + 15)] {
            #expect(throws: UsageError.unreadableTokenCache) {
                let plain = try SafeStorage.decrypt(base64: Data(damaged).base64EncodedString(), key: key)
                _ = try TokenCache.select(decrypted: plain, accountUUID: nil)
            }
        }
        #expect(throws: UsageError.unreadableTokenCache) { try SafeStorage.decrypt(base64: Self.fixture, key: Data(count: 5)) }
    }

    @Test(arguments: ["nope", "wrong", "another", "x"])
    func wrongKeyFails(password: String) {
        let wrong = SafeStorage.deriveKey(password: Data(password.utf8))
        // A wrong key usually fails the padding check, but can pass it and give garbage;
        // either way the read reports an unreadable login.
        #expect(throws: UsageError.unreadableTokenCache) {
            let plain = try SafeStorage.decrypt(base64: Self.fixture, key: wrong)
            _ = try TokenCache.select(decrypted: plain, accountUUID: nil)
        }
    }
}
