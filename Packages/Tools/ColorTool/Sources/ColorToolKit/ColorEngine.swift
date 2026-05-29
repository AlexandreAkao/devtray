import DevTrayCore
import Foundation

public struct ColorValue: Equatable, Sendable {
    public let r: Int // 0–255
    public let g: Int
    public let b: Int
    public let a: Double // 0–1
    public init(r: Int, g: Int, b: Int, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public var hex: String {
        if a < 1 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, Int((a * 255).rounded()))
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var rgbString: String {
        a < 1 ? "rgba(\(r), \(g), \(b), \(alphaText))" : "rgb(\(r), \(g), \(b))"
    }

    public var hslString: String {
        let (h, s, l) = ColorEngine.rgbToHSL(r: r, g: g, b: b)
        let hi = Int(h.rounded()) % 360, si = Int((s * 100).rounded()), li = Int((l * 100).rounded())
        return a < 1 ? "hsla(\(hi), \(si)%, \(li)%, \(alphaText))" : "hsl(\(hi), \(si)%, \(li)%)"
    }

    private var alphaText: String { String(format: "%g", (a * 1000).rounded() / 1000) }
}

public enum ColorEngine {
    public static func parse(_ input: String) -> Result<ColorValue, ToolError> {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { return parseHex(s) }
        let lower = s.lowercased()
        if lower.hasPrefix("rgb") { return parseRGB(s) }
        if lower.hasPrefix("hsl") { return parseHSL(s) }
        return .failure(.invalidInput(reason: "Unrecognized color format. Use #hex, rgb(), or hsl()."))
    }

    private static func parseHex(_ s: String) -> Result<ColorValue, ToolError> {
        var hex = String(s.dropFirst())
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6 || hex.count == 8, let n = UInt64(hex, radix: 16) else {
            return .failure(.invalidInput(reason: "Hex color must be 3, 6, or 8 valid digits."))
        }
        if hex.count == 6 {
            return .success(ColorValue(r: Int((n >> 16) & 0xFF), g: Int((n >> 8) & 0xFF), b: Int(n & 0xFF), a: 1))
        }
        return .success(ColorValue(r: Int((n >> 24) & 0xFF), g: Int((n >> 16) & 0xFF),
                                   b: Int((n >> 8) & 0xFF), a: Double(Int(n & 0xFF)) / 255))
    }

    private static func parseRGB(_ s: String) -> Result<ColorValue, ToolError> {
        let n = numbers(in: s)
        guard n.count == 3 || n.count == 4 else { return .failure(.invalidInput(reason: "rgb() needs 3 or 4 values.")) }
        // CSS percentage channels: numbers(in:) strips the "%", so scale 0–100 → 0–255.
        let scale = s.contains("%") ? 2.55 : 1.0
        let a = n.count == 4 ? max(0, min(1, n[3])) : 1
        return .success(ColorValue(r: clamp255(n[0] * scale), g: clamp255(n[1] * scale), b: clamp255(n[2] * scale), a: a))
    }

    private static func parseHSL(_ s: String) -> Result<ColorValue, ToolError> {
        let n = numbers(in: s)
        guard n.count == 3 || n.count == 4 else { return .failure(.invalidInput(reason: "hsl() needs 3 or 4 values.")) }
        let a = n.count == 4 ? max(0, min(1, n[3])) : 1
        let (r, g, b) = hslToRGB(h: n[0], s: max(0, min(1, n[1] / 100)), l: max(0, min(1, n[2] / 100)))
        return .success(ColorValue(r: r, g: g, b: b, a: a))
    }

    private static func numbers(in s: String) -> [Double] {
        guard let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")"), open < close else { return [] }
        return s[s.index(after: open) ..< close]
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")) }
    }

    private static func clamp255(_ d: Double) -> Int { max(0, min(255, Int(d.rounded()))) }

    static func rgbToHSL(r: Int, g: Int, b: Int) -> (h: Double, s: Double, l: Double) {
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let mx = max(rf, gf, bf), mn = min(rf, gf, bf), d = mx - mn
        let l = (mx + mn) / 2
        guard d != 0 else { return (0, 0, l) }
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == rf { h = (gf - bf) / d + (gf < bf ? 6 : 0) }
        else if mx == gf { h = (bf - rf) / d + 2 }
        else { h = (rf - gf) / d + 4 }
        return (h * 60, s, l)
    }

    static func hslToRGB(h: Double, s: Double, l: Double) -> (Int, Int, Int) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case 0 ..< 1: (r1, g1, b1) = (c, x, 0)
        case 1 ..< 2: (r1, g1, b1) = (x, c, 0)
        case 2 ..< 3: (r1, g1, b1) = (0, c, x)
        case 3 ..< 4: (r1, g1, b1) = (0, x, c)
        case 4 ..< 5: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        let m = l - c / 2
        return (Int(((r1 + m) * 255).rounded()), Int(((g1 + m) * 255).rounded()), Int(((b1 + m) * 255).rounded()))
    }
}
