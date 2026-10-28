import Foundation
import CoreFoundation

public enum Privacy {
    public static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }
    public static func identifier(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty, string != ".", string != "..", string.utf8.count <= 180,
              string.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_:.@")).contains($0) }) else { return nil }
        return string
    }
    public static func title(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty, text.utf8.count <= 512,
              !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return text
    }
}
