import Foundation
import os

/// The one encoder and decoder for Codable values stored as JSON `Data` on models (PRD §6.1,
/// as PhysiMate's). Empty `Data` means never set; a failure is logged and the accessor falls
/// back to its default.
enum ModelJSON {
    private static let logger = Logger(subsystem: "com.bowerhaus.Earwig", category: "ModelJSON")

    static func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(value)
        } catch {
            logger.error("Encoding \(String(describing: T.self)) failed: \(error.localizedDescription)")
            return Data()
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        guard !data.isEmpty else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Decoding \(String(describing: T.self)) failed: \(error.localizedDescription)")
            return nil
        }
    }
}
