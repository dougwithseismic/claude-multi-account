import CommonCrypto
import Foundation
import Security

/// Electron's safeStorage on macOS (Chromium OSCrypt): a password in the Keychain,
/// stretched into an AES-128 key that encrypts values as "v10" + AES-128-CBC.
public enum SafeStorage {
    static let keychainService = "Claude Safe Storage"
    static let keychainAccount = "Claude Key"

    /// Reads Claude's safeStorage password. macOS asks the user the first time;
    /// "Always Allow" stops it asking again for this binary.
    public static func keychainPassword() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw UsageError.keychain(status) }
            return data
        case errSecItemNotFound:
            throw UsageError.keychainItemMissing
        default:
            throw UsageError.keychain(status)
        }
    }

    /// PBKDF2-HMAC-SHA1, salt "saltysalt", 1003 rounds, 16 bytes.
    public static func deriveKey(password: Data) -> Data {
        let salt = Data("saltysalt".utf8)
        var key = Data(count: kCCKeySizeAES128)
        let status = key.withUnsafeMutableBytes { keyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self), password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003,
                        keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), kCCKeySizeAES128
                    )
                }
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 failed: \(status)")
        return key
    }

    /// Decrypts a base64 "v10" value from config.json.
    public static func decrypt(base64: String, key: Data) throws -> Data {
        guard let blob = Data(base64Encoded: base64), blob.count > 3 else { throw UsageError.unreadableTokenCache }
        guard blob.prefix(3) == Data("v10".utf8) else { throw UsageError.unknownEncryption }
        return try crypt(CCOperation(kCCDecrypt), blob.dropFirst(3), key: key)
    }

    /// The reverse of `decrypt`, used by tests to build fixtures.
    static func encrypt(_ plaintext: Data, key: Data) throws -> String {
        let body = try crypt(CCOperation(kCCEncrypt), plaintext, key: key)
        return (Data("v10".utf8) + body).base64EncodedString()
    }

    private static func crypt(_ operation: CCOperation, _ input: Data, key: Data) throws -> Data {
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var output = Data(count: input.count + kCCBlockSizeAES128)
        var written = 0
        let capacity = output.count
        let status = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { inp in
                key.withUnsafeBytes { k in
                    iv.withUnsafeBytes { v in
                        CCCrypt(
                            operation, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                            k.baseAddress, key.count, v.baseAddress,
                            inp.baseAddress, input.count,
                            out.baseAddress, capacity, &written
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw UsageError.unreadableTokenCache }
        return output.prefix(written)
    }
}
