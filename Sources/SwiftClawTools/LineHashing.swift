import CryptoKit
import Foundation

enum LineHashing {
    static func hash(_ line: String) -> String {
        let digest = SHA256.hash(data: Data(line.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}
