//
//  GedcomTextDecoder.swift
//  GEDCOM Viewer
//
//  Created by Codex on 10/11/2025.
//

import Foundation

/// Decodes raw GEDCOM data to Unicode, respecting the character set declared in the file header.
struct GedcomTextDecoder {
    private let anselDecoder = AnselDecoder()

    func decode(_ data: Data) throws -> String {
        guard !data.isEmpty else { return "" }

        let bom = ByteOrderMark(data: data)
        let declaredCharset = declaredCharset(in: data)

        let strategies = decodingStrategies(bom: bom, declared: declaredCharset)
        for strategy in strategies {
            if let decoded = decode(data, using: strategy) {
                return decoded
            }
        }

        throw GedcomParserError.invalidEncoding
    }

    private func decode(_ data: Data, using strategy: DecodingStrategy) -> String? {
        switch strategy {
        case .utf8:
            return String(data: data, encoding: .utf8)
        case .utf16LittleEndian:
            return String(data: data, encoding: .utf16LittleEndian)
        case .utf16BigEndian:
            return String(data: data, encoding: .utf16BigEndian)
        case .windowsCP1252:
            return String(data: data, encoding: .windowsCP1252)
        case .isoLatin1:
            return String(data: data, encoding: .isoLatin1)
        case .ascii:
            return String(data: data, encoding: .ascii)
        case .macOSRoman:
            return String(data: data, encoding: .macOSRoman)
        case .ansel:
            return anselDecoder.decode(data)
        }
    }

    private func decodingStrategies(bom: ByteOrderMark?, declared: DeclaredCharset?) -> [DecodingStrategy] {
        var order: [DecodingStrategy] = []
        if let bomStrategy = bom?.strategy {
            order.append(bomStrategy)
        }
        if let declared {
            order.append(contentsOf: declared.preferredStrategies)
        }
        order.append(contentsOf: DecodingStrategy.defaultFallbacks)
        return order.removingDuplicates()
    }

    private func declaredCharset(in data: Data) -> DeclaredCharset? {
        // The header is guaranteed to be ASCII, so lossy UTF‑8 is safe for scanning.
        let headerWindow = String(decoding: data.prefix(8192), as: UTF8.self)
        for rawLine in headerWindow.split(whereSeparator: \.isNewline) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("1 CHAR") else { continue }
            let value = trimmed.dropFirst("1 CHAR".count).trimmingCharacters(in: .whitespaces)
            if let charset = DeclaredCharset(rawValue: value) {
                return charset
            }
        }
        return nil
    }
}

// MARK: - Declared charset bookkeeping

private enum DecodingStrategy: Hashable {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian
    case windowsCP1252
    case isoLatin1
    case ascii
    case macOSRoman
    case ansel

    static let defaultFallbacks: [DecodingStrategy] = [
        .utf8,
        .windowsCP1252,
        .macOSRoman,
        .isoLatin1,
        .ansel,
        .utf16LittleEndian,
        .utf16BigEndian
    ]
}

private enum ByteOrderMark {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian

    init?(data: Data) {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            self = .utf8
        } else if data.starts(with: [0xFF, 0xFE]) {
            self = .utf16LittleEndian
        } else if data.starts(with: [0xFE, 0xFF]) {
            self = .utf16BigEndian
        } else {
            return nil
        }
    }

    var strategy: DecodingStrategy {
        switch self {
        case .utf8:
            return .utf8
        case .utf16LittleEndian:
            return .utf16LittleEndian
        case .utf16BigEndian:
            return .utf16BigEndian
        }
    }
}

private enum DeclaredCharset {
    case utf8
    case unicode
    case ansel
    case ansi
    case ascii
    case macintosh
    case other(String)

    init?(rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "UTF-8", "UTF8":
            self = .utf8
        case "UNICODE", "UTF-16", "UTF16":
            self = .unicode
        case "ANSEL":
            self = .ansel
        case "ANSI", "WINDOWS", "IBMPC", "IBM PC":
            self = .ansi
        case "ASCII":
            self = .ascii
        case "MACINTOSH", "MAC":
            self = .macintosh
        default:
            self = .other(normalized)
        }
    }

    var preferredStrategies: [DecodingStrategy] {
        switch self {
        case .utf8:
            return [.utf8]
        case .unicode:
            return [.utf16LittleEndian, .utf16BigEndian]
        case .ansel:
            return [.ansel, .windowsCP1252]
        case .ansi:
            return [.windowsCP1252, .isoLatin1]
        case .ascii:
            return [.ascii, .utf8]
        case .macintosh:
            return [.macOSRoman]
        case .other(let value):
            if value.contains("UTF-16") || value.contains("UTF16") {
                return [.utf16LittleEndian, .utf16BigEndian]
            }
            if value.contains("UTF-8") || value.contains("UTF8") {
                return [.utf8]
            }
            return []
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen: Set<Element> = []
        var result: [Element] = []
        for element in self {
            if seen.insert(element).inserted {
                result.append(element)
            }
        }
        return result
    }
}

// MARK: - ANSEL decoder

private struct AnselDecoder {
    // Mapping tables derived from the python-ansel project (MIT License).
    func decode(_ data: Data) -> String {
        var scalars: [UnicodeScalar] = []
        var modifiers: [UnicodeScalar] = []
        let space = UnicodeScalar(0x20)!
        let replacement = UnicodeScalar(0xFFFD)!

        for byte in data {
            if let scalar = Self.anselCharMap[byte] {
                scalars.append(scalar)
                if !modifiers.isEmpty {
                    scalars.append(contentsOf: modifiers)
                    modifiers.removeAll(keepingCapacity: true)
                }
            } else if let control = Self.anselControlMap[byte] {
                if !modifiers.isEmpty {
                    scalars.append(space)
                    scalars.append(contentsOf: modifiers)
                    modifiers.removeAll(keepingCapacity: true)
                }
                scalars.append(control)
            } else if let modifier = Self.anselModifierMap[byte] {
                modifiers.insert(modifier, at: 0)
            } else {
                scalars.append(replacement)
                if !modifiers.isEmpty {
                    scalars.append(contentsOf: modifiers)
                    modifiers.removeAll(keepingCapacity: true)
                }
            }
        }

        if !modifiers.isEmpty {
            scalars.append(space)
            scalars.append(contentsOf: modifiers)
        }

        return String(String.UnicodeScalarView(scalars))
    }

    private static let anselControlMap: [UInt8: UnicodeScalar] = [
        0x00: UnicodeScalar(0x0000)!,
        0x01: UnicodeScalar(0x0001)!,
        0x02: UnicodeScalar(0x0002)!,
        0x03: UnicodeScalar(0x0003)!,
        0x04: UnicodeScalar(0x0004)!,
        0x05: UnicodeScalar(0x0005)!,
        0x06: UnicodeScalar(0x0006)!,
        0x07: UnicodeScalar(0x0007)!,
        0x08: UnicodeScalar(0x0008)!,
        0x09: UnicodeScalar(0x0009)!,
        0x0A: UnicodeScalar(0x000A)!,
        0x0B: UnicodeScalar(0x000B)!,
        0x0C: UnicodeScalar(0x000C)!,
        0x0D: UnicodeScalar(0x000D)!,
        0x0E: UnicodeScalar(0x000E)!,
        0x0F: UnicodeScalar(0x000F)!,
        0x10: UnicodeScalar(0x0010)!,
        0x11: UnicodeScalar(0x0011)!,
        0x12: UnicodeScalar(0x0012)!,
        0x13: UnicodeScalar(0x0013)!,
        0x14: UnicodeScalar(0x0014)!,
        0x15: UnicodeScalar(0x0015)!,
        0x16: UnicodeScalar(0x0016)!,
        0x17: UnicodeScalar(0x0017)!,
        0x18: UnicodeScalar(0x0018)!,
        0x19: UnicodeScalar(0x0019)!,
        0x1A: UnicodeScalar(0x001A)!,
        0x1B: UnicodeScalar(0x001B)!,
        0x1C: UnicodeScalar(0x001C)!,
        0x1D: UnicodeScalar(0x001D)!,
        0x1E: UnicodeScalar(0x001E)!,
        0x1F: UnicodeScalar(0x001F)!,
    ]

    private static let anselCharMap: [UInt8: UnicodeScalar] = [
        0x20: UnicodeScalar(0x0020)!,
        0x21: UnicodeScalar(0x0021)!,
        0x22: UnicodeScalar(0x0022)!,
        0x23: UnicodeScalar(0x0023)!,
        0x24: UnicodeScalar(0x0024)!,
        0x25: UnicodeScalar(0x0025)!,
        0x26: UnicodeScalar(0x0026)!,
        0x27: UnicodeScalar(0x0027)!,
        0x28: UnicodeScalar(0x0028)!,
        0x29: UnicodeScalar(0x0029)!,
        0x2A: UnicodeScalar(0x002A)!,
        0x2B: UnicodeScalar(0x002B)!,
        0x2C: UnicodeScalar(0x002C)!,
        0x2D: UnicodeScalar(0x002D)!,
        0x2E: UnicodeScalar(0x002E)!,
        0x2F: UnicodeScalar(0x002F)!,
        0x30: UnicodeScalar(0x0030)!,
        0x31: UnicodeScalar(0x0031)!,
        0x32: UnicodeScalar(0x0032)!,
        0x33: UnicodeScalar(0x0033)!,
        0x34: UnicodeScalar(0x0034)!,
        0x35: UnicodeScalar(0x0035)!,
        0x36: UnicodeScalar(0x0036)!,
        0x37: UnicodeScalar(0x0037)!,
        0x38: UnicodeScalar(0x0038)!,
        0x39: UnicodeScalar(0x0039)!,
        0x3A: UnicodeScalar(0x003A)!,
        0x3B: UnicodeScalar(0x003B)!,
        0x3C: UnicodeScalar(0x003C)!,
        0x3D: UnicodeScalar(0x003D)!,
        0x3E: UnicodeScalar(0x003E)!,
        0x3F: UnicodeScalar(0x003F)!,
        0x40: UnicodeScalar(0x0040)!,
        0x41: UnicodeScalar(0x0041)!,
        0x42: UnicodeScalar(0x0042)!,
        0x43: UnicodeScalar(0x0043)!,
        0x44: UnicodeScalar(0x0044)!,
        0x45: UnicodeScalar(0x0045)!,
        0x46: UnicodeScalar(0x0046)!,
        0x47: UnicodeScalar(0x0047)!,
        0x48: UnicodeScalar(0x0048)!,
        0x49: UnicodeScalar(0x0049)!,
        0x4A: UnicodeScalar(0x004A)!,
        0x4B: UnicodeScalar(0x004B)!,
        0x4C: UnicodeScalar(0x004C)!,
        0x4D: UnicodeScalar(0x004D)!,
        0x4E: UnicodeScalar(0x004E)!,
        0x4F: UnicodeScalar(0x004F)!,
        0x50: UnicodeScalar(0x0050)!,
        0x51: UnicodeScalar(0x0051)!,
        0x52: UnicodeScalar(0x0052)!,
        0x53: UnicodeScalar(0x0053)!,
        0x54: UnicodeScalar(0x0054)!,
        0x55: UnicodeScalar(0x0055)!,
        0x56: UnicodeScalar(0x0056)!,
        0x57: UnicodeScalar(0x0057)!,
        0x58: UnicodeScalar(0x0058)!,
        0x59: UnicodeScalar(0x0059)!,
        0x5A: UnicodeScalar(0x005A)!,
        0x5B: UnicodeScalar(0x005B)!,
        0x5C: UnicodeScalar(0x005C)!,
        0x5D: UnicodeScalar(0x005D)!,
        0x5E: UnicodeScalar(0x005E)!,
        0x5F: UnicodeScalar(0x005F)!,
        0x60: UnicodeScalar(0x0060)!,
        0x61: UnicodeScalar(0x0061)!,
        0x62: UnicodeScalar(0x0062)!,
        0x63: UnicodeScalar(0x0063)!,
        0x64: UnicodeScalar(0x0064)!,
        0x65: UnicodeScalar(0x0065)!,
        0x66: UnicodeScalar(0x0066)!,
        0x67: UnicodeScalar(0x0067)!,
        0x68: UnicodeScalar(0x0068)!,
        0x69: UnicodeScalar(0x0069)!,
        0x6A: UnicodeScalar(0x006A)!,
        0x6B: UnicodeScalar(0x006B)!,
        0x6C: UnicodeScalar(0x006C)!,
        0x6D: UnicodeScalar(0x006D)!,
        0x6E: UnicodeScalar(0x006E)!,
        0x6F: UnicodeScalar(0x006F)!,
        0x70: UnicodeScalar(0x0070)!,
        0x71: UnicodeScalar(0x0071)!,
        0x72: UnicodeScalar(0x0072)!,
        0x73: UnicodeScalar(0x0073)!,
        0x74: UnicodeScalar(0x0074)!,
        0x75: UnicodeScalar(0x0075)!,
        0x76: UnicodeScalar(0x0076)!,
        0x77: UnicodeScalar(0x0077)!,
        0x78: UnicodeScalar(0x0078)!,
        0x79: UnicodeScalar(0x0079)!,
        0x7A: UnicodeScalar(0x007A)!,
        0x7B: UnicodeScalar(0x007B)!,
        0x7C: UnicodeScalar(0x007C)!,
        0x7D: UnicodeScalar(0x007D)!,
        0x7E: UnicodeScalar(0x007E)!,
        0x7F: UnicodeScalar(0x007F)!,
        0xA1: UnicodeScalar(0x0141)!,
        0xA2: UnicodeScalar(0x00D8)!,
        0xA3: UnicodeScalar(0x0110)!,
        0xA4: UnicodeScalar(0x00DE)!,
        0xA5: UnicodeScalar(0x00C6)!,
        0xA6: UnicodeScalar(0x0152)!,
        0xA7: UnicodeScalar(0x02B9)!,
        0xA8: UnicodeScalar(0x00B7)!,
        0xA9: UnicodeScalar(0x266D)!,
        0xAA: UnicodeScalar(0x00AE)!,
        0xAB: UnicodeScalar(0x00B1)!,
        0xAC: UnicodeScalar(0x01A0)!,
        0xAD: UnicodeScalar(0x01AF)!,
        0xAE: UnicodeScalar(0x02BC)!,
        0xB0: UnicodeScalar(0x02BB)!,
        0xB1: UnicodeScalar(0x0142)!,
        0xB2: UnicodeScalar(0x00F8)!,
        0xB3: UnicodeScalar(0x0111)!,
        0xB4: UnicodeScalar(0x00FE)!,
        0xB5: UnicodeScalar(0x00E6)!,
        0xB6: UnicodeScalar(0x0153)!,
        0xB7: UnicodeScalar(0x02BA)!,
        0xB8: UnicodeScalar(0x0131)!,
        0xB9: UnicodeScalar(0x00A3)!,
        0xBA: UnicodeScalar(0x00F0)!,
        0xBC: UnicodeScalar(0x01A1)!,
        0xBD: UnicodeScalar(0x01B0)!,
        0xC0: UnicodeScalar(0x00B0)!,
        0xC1: UnicodeScalar(0x2113)!,
        0xC2: UnicodeScalar(0x2117)!,
        0xC3: UnicodeScalar(0x00A9)!,
        0xC4: UnicodeScalar(0x266F)!,
        0xC5: UnicodeScalar(0x00BF)!,
        0xC6: UnicodeScalar(0x00A1)!,
    ]

    private static let anselModifierMap: [UInt8: UnicodeScalar] = [
        0xE0: UnicodeScalar(0x0309)!,
        0xE1: UnicodeScalar(0x0300)!,
        0xE2: UnicodeScalar(0x0301)!,
        0xE3: UnicodeScalar(0x0302)!,
        0xE4: UnicodeScalar(0x0303)!,
        0xE5: UnicodeScalar(0x0304)!,
        0xE6: UnicodeScalar(0x0306)!,
        0xE7: UnicodeScalar(0x0307)!,
        0xE8: UnicodeScalar(0x0308)!,
        0xE9: UnicodeScalar(0x030C)!,
        0xEA: UnicodeScalar(0x030A)!,
        0xEB: UnicodeScalar(0xFE20)!,
        0xEC: UnicodeScalar(0xFE21)!,
        0xED: UnicodeScalar(0x0315)!,
        0xEE: UnicodeScalar(0x030B)!,
        0xEF: UnicodeScalar(0x0310)!,
        0xF0: UnicodeScalar(0x0327)!,
        0xF1: UnicodeScalar(0x0328)!,
        0xF2: UnicodeScalar(0x0323)!,
        0xF3: UnicodeScalar(0x0324)!,
        0xF4: UnicodeScalar(0x0325)!,
        0xF5: UnicodeScalar(0x0333)!,
        0xF6: UnicodeScalar(0x0332)!,
        0xF7: UnicodeScalar(0x0326)!,
        0xF8: UnicodeScalar(0x031C)!,
        0xF9: UnicodeScalar(0x032E)!,
        0xFA: UnicodeScalar(0xFE22)!,
        0xFB: UnicodeScalar(0xFE23)!,
        0xFE: UnicodeScalar(0x0313)!,
    ]
}
