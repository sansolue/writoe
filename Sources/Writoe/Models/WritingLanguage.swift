import Foundation
import AppKit

struct WritingLanguage: Identifiable, Hashable {
    let id: String          // BCP 47 tag
    let name: String        // English name
    let nativeName: String  // Name in the language itself
    let isRTL: Bool
    let scriptSample: Unicode.Scalar  // Representative char for font filtering

    // MARK: - Supported languages

    static let all: [WritingLanguage] = [
        // Latin-script languages (curated font list, no slow filtering needed)
        .init(id: "en",    name: "English",              nativeName: "English",           isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "fr",    name: "French",               nativeName: "Français",          isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "de",    name: "German",               nativeName: "Deutsch",           isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "es",    name: "Spanish",              nativeName: "Español",           isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "pt",    name: "Portuguese",           nativeName: "Português",         isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "it",    name: "Italian",              nativeName: "Italiano",          isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "nl",    name: "Dutch",                nativeName: "Nederlands",        isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        .init(id: "pl",    name: "Polish",               nativeName: "Polski",            isRTL: false, scriptSample: Unicode.Scalar(0x0041)!),
        // Cyrillic
        .init(id: "ru",    name: "Russian",              nativeName: "Русский",           isRTL: false, scriptSample: Unicode.Scalar(0x0410)!),
        .init(id: "uk",    name: "Ukrainian",            nativeName: "Українська",        isRTL: false, scriptSample: Unicode.Scalar(0x0410)!),
        // Indic / South Asian
        .init(id: "si",    name: "Sinhala",              nativeName: "සිංහල",            isRTL: false, scriptSample: Unicode.Scalar(0x0D85)!),
        .init(id: "hi",    name: "Hindi",                nativeName: "हिन्दी",           isRTL: false, scriptSample: Unicode.Scalar(0x0905)!),
        .init(id: "mr",    name: "Marathi",              nativeName: "मराठी",            isRTL: false, scriptSample: Unicode.Scalar(0x0905)!),
        .init(id: "ta",    name: "Tamil",                nativeName: "தமிழ்",            isRTL: false, scriptSample: Unicode.Scalar(0x0B85)!),
        .init(id: "te",    name: "Telugu",               nativeName: "తెలుగు",           isRTL: false, scriptSample: Unicode.Scalar(0x0C05)!),
        .init(id: "kn",    name: "Kannada",              nativeName: "ಕನ್ನಡ",            isRTL: false, scriptSample: Unicode.Scalar(0x0C85)!),
        .init(id: "ml",    name: "Malayalam",            nativeName: "മലയാളം",           isRTL: false, scriptSample: Unicode.Scalar(0x0D05)!),
        .init(id: "bn",    name: "Bengali",              nativeName: "বাংলা",            isRTL: false, scriptSample: Unicode.Scalar(0x0985)!),
        .init(id: "gu",    name: "Gujarati",             nativeName: "ગુજરાતી",          isRTL: false, scriptSample: Unicode.Scalar(0x0A85)!),
        .init(id: "pa",    name: "Punjabi",              nativeName: "ਪੰਜਾਬੀ",           isRTL: false, scriptSample: Unicode.Scalar(0x0A05)!),
        // Southeast Asian
        .init(id: "th",    name: "Thai",                 nativeName: "ภาษาไทย",          isRTL: false, scriptSample: Unicode.Scalar(0x0E01)!),
        .init(id: "my",    name: "Burmese",              nativeName: "မြန်မာဘာသာ",       isRTL: false, scriptSample: Unicode.Scalar(0x1000)!),
        .init(id: "km",    name: "Khmer",                nativeName: "ភាសាខ្មែរ",        isRTL: false, scriptSample: Unicode.Scalar(0x1780)!),
        // East Asian
        .init(id: "zh-Hans", name: "Chinese (Simplified)",  nativeName: "中文（简体）",  isRTL: false, scriptSample: Unicode.Scalar(0x4E2D)!),
        .init(id: "zh-Hant", name: "Chinese (Traditional)", nativeName: "中文（繁體）",  isRTL: false, scriptSample: Unicode.Scalar(0x4E2D)!),
        .init(id: "ja",    name: "Japanese",             nativeName: "日本語",           isRTL: false, scriptSample: Unicode.Scalar(0x3041)!),
        .init(id: "ko",    name: "Korean",               nativeName: "한국어",           isRTL: false, scriptSample: Unicode.Scalar(0xAC00)!),
        // RTL languages
        .init(id: "ar",    name: "Arabic",               nativeName: "العربية",          isRTL: true,  scriptSample: Unicode.Scalar(0x0639)!),
        .init(id: "he",    name: "Hebrew",               nativeName: "עברית",            isRTL: true,  scriptSample: Unicode.Scalar(0x05D0)!),
        .init(id: "fa",    name: "Persian",              nativeName: "فارسی",            isRTL: true,  scriptSample: Unicode.Scalar(0x0641)!),
        .init(id: "ur",    name: "Urdu",                 nativeName: "اردو",             isRTL: true,  scriptSample: Unicode.Scalar(0x0627)!),
    ]

    static func find(id: String) -> WritingLanguage {
        all.first { $0.id == id } ?? all[0]
    }

    // MARK: - Font filtering

    /// Returns a list of fonts appropriate for writing in this language.
    /// Latin/Cyrillic use a curated list; other scripts filter system fonts by character coverage.
    static func fontNames(for language: WritingLanguage) -> [String] {
        let base = language.id.components(separatedBy: "-").first ?? language.id

        let latinCodes  = Set(["en","fr","de","es","pt","it","nl","pl","sv","no","da","fi","cs","sk","ro","hr","hu"])
        let cyrillicCodes = Set(["ru","uk","bg","sr","mk","be"])

        if latinCodes.contains(base)   { return latinCuratedFonts }
        if cyrillicCodes.contains(base){ return cyrillicCuratedFonts }

        // Non-Latin: filter installed fonts by character coverage
        let sample = language.scriptSample
        return NSFontManager.shared.availableFonts.filter { name in
            guard let nsf = NSFont(name: name, size: 12) else { return false }
            let cs = CTFontCopyCharacterSet(nsf as CTFont) as CharacterSet
            return cs.contains(sample)
        }.sorted()
    }

    private static let latinCuratedFonts = [
        "Georgia", "Times New Roman", "Palatino", "Baskerville",
        "Didot", "Hoefler Text", "Garamond", "Caslon",
        "Helvetica Neue", "Arial", "Verdana", "Optima",
        "Gill Sans", "Futura", "Trebuchet MS",
        "Courier New", "Menlo", "Monaco"
    ]

    private static let cyrillicCuratedFonts = [
        "Times New Roman", "Arial", "Helvetica Neue",
        "Verdana", "Georgia", "PT Serif", "PT Sans"
    ]

    // MARK: - Default font for language

    static func defaultFont(for language: WritingLanguage) -> String {
        let base = language.id.components(separatedBy: "-").first ?? language.id
        switch base {
        case "ar", "fa", "ur": return "Geeza Pro"
        case "he":             return "Times New Roman"
        case "hi","mr","ne":   return "Devanagari MT"
        case "ta":             return "Tamil MN"
        case "te":             return "Telugu MN"
        case "ml":             return "Malayalam MN"
        case "kn":             return "Kannada MN"
        case "bn","gu","pa":   return "Kohinoor Devanagari"
        case "si":             return "Sinhala MN"
        case "th":             return "Thonburi"
        case "zh","ja":        return "Hiragino Mincho ProN"
        case "ko":             return "AppleMyungjo"
        case "ru","uk","bg":   return "PT Serif"
        default:               return "Georgia"
        }
    }
}
