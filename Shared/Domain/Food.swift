import Foundation

/// Halal information. FitTrack never certifies a product itself: it only reports
/// what the data source declares, or ingredients that are commonly considered non-halal.
enum HalalStatus: String, Codable, CaseIterable {
    /// The product carries a "halal" label in Open Food Facts (user-contributed, not a certification).
    case declaredHalal
    /// Raw, unprocessed food from FitTrack's built-in list that is generally considered halal (eggs, fish, plants…).
    case naturallyHalal
    /// No animal ingredient and no alcohol detected (plant-based product), not certified.
    case plantBased
    /// Meat/poultry: halal status depends on the origin and certification.
    case dependsOnOrigin
    /// No reliable information.
    case unknown
    /// A potentially non-halal ingredient was detected (pork, alcohol, gelatin…).
    case potentiallyNonHalal

    var label: String {
        switch self {
        case .declaredHalal: return "Déclaré halal (non vérifié)"
        case .naturallyHalal: return "Aliment brut, généralement halal"
        case .plantBased: return "Végétal, sans alcool détecté"
        case .dependsOnOrigin: return "Selon provenance"
        case .unknown: return "Statut halal inconnu"
        case .potentiallyNonHalal: return "Potentiellement non halal"
        }
    }

    var explanation: String {
        switch self {
        case .declaredHalal:
            return "Le label « halal » est indiqué sur la fiche Open Food Facts. Cette information est saisie par des contributeurs et ne remplace pas une certification : vérifiez le logo de l'organisme certificateur sur l'emballage."
        case .naturallyHalal:
            return "Aliment brut non transformé (végétal, œuf, lait, poisson…) généralement considéré comme halal. Pour un produit transformé, vérifiez l'emballage."
        case .plantBased:
            return "Aucun ingrédient d'origine animale ni alcool n'a été détecté dans la liste d'ingrédients disponible. Ce n'est pas une certification."
        case .dependsOnOrigin:
            return "Le statut halal d'une viande dépend de l'abattage et de la certification. Vérifiez auprès de votre boucher ou sur l'emballage."
        case .unknown:
            return "Les informations disponibles ne permettent pas de déterminer le statut halal de ce produit."
        case .potentiallyNonHalal:
            return "Un ou plusieurs ingrédients généralement considérés comme non halal ont été détectés."
        }
    }

    var symbol: String {
        switch self {
        case .declaredHalal: return "checkmark.seal"
        case .naturallyHalal: return "leaf.circle"
        case .plantBased: return "leaf"
        case .dependsOnOrigin: return "questionmark.circle"
        case .unknown: return "questionmark.circle"
        case .potentiallyNonHalal: return "exclamationmark.triangle.fill"
        }
    }

    /// Sort rank when halal preference is on (lower is shown first).
    var preferenceRank: Int {
        switch self {
        case .declaredHalal: return 0
        case .naturallyHalal: return 1
        case .plantBased: return 1
        case .dependsOnOrigin: return 2
        case .unknown: return 3
        case .potentiallyNonHalal: return 4
        }
    }
}

/// A food that can be added to the journal (from the built-in database, Open Food Facts or manual entry).
struct FoodItem: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var brand: String
    var barcode: String
    var per100g: Macros
    /// Typical serving size in grams, when known.
    var servingGrams: Double?
    var halal: HalalStatus
    var halalReasons: [String]
    var source: FoodSource
    var imageURL: URL? = nil

    var displayName: String { brand.isEmpty ? name : "\(name) – \(brand)" }
}

/// Detects ingredients commonly considered non-halal in ingredient lists and tags.
enum HalalAnalyzer {
    /// Keyword → human readable (French) reason.
    private static let nonHalalKeywords: [(String, String)] = [
        ("pork", "porc"), ("porc", "porc"), ("pig", "porc"), ("cochon", "porc"),
        ("bacon", "bacon"), ("lardon", "lardons"), ("saindoux", "saindoux"), ("lard", "lard"),
        ("jambon", "jambon"), ("ham", "jambon"), ("chorizo", "chorizo (porc)"), ("salami", "salami"),
        ("pancetta", "pancetta"), ("prosciutto", "prosciutto"),
        ("gelatin", "gélatine (origine souvent inconnue)"), ("gélatine", "gélatine (origine souvent inconnue)"),
        ("gelatine", "gélatine (origine souvent inconnue)"), ("e441", "gélatine (E441)"),
        ("alcohol", "alcool"), ("alcool", "alcool"), ("ethanol", "alcool"),
        ("wine", "vin"), ("vin ", "vin"), ("vin,", "vin"), ("beer", "bière"), ("bière", "bière"),
        ("rhum", "rhum"), ("rum", "rhum"), ("whisky", "whisky"), ("cognac", "cognac"), ("liqueur", "liqueur"),
        ("e120", "carmin (E120)"), ("carmine", "carmin (E120)"), ("cochineal", "carmin (E120)"),
    ]

    private static let meatKeywords = ["beef", "boeuf", "bœuf", "chicken", "poulet", "lamb", "agneau",
                                       "veal", "veau", "turkey", "dinde", "mutton", "mouton", "viande", "meat"]

    /// Returns the matched reasons (deduplicated, French).
    static func nonHalalReasons(in texts: [String]) -> [String] {
        let haystack = " " + texts.joined(separator: " ").lowercased()
            .replacingOccurrences(of: "en:", with: " ")
            .replacingOccurrences(of: "fr:", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            // Wine vinegar is generally considered permissible (the alcohol is transformed).
            .replacingOccurrences(of: "vinaigre de vin", with: "vinaigre")
            .replacingOccurrences(of: "wine vinegar", with: "vinegar") + " "
        var reasons: [String] = []
        for (keyword, reason) in nonHalalKeywords where containsWord(keyword, in: haystack) {
            if !reasons.contains(reason) { reasons.append(reason) }
        }
        return reasons
    }

    static func containsMeat(in texts: [String]) -> Bool {
        let haystack = " " + texts.joined(separator: " ").lowercased().replacingOccurrences(of: "en:", with: " ") + " "
        return meatKeywords.contains { containsWord($0, in: haystack) }
    }

    /// Word-boundary match so that "jambon" does not match "ham" inside "champignon".
    private static func containsWord(_ word: String, in text: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !trimmed.isEmpty else { return false }
        let pattern = "(^|[^\\p{L}])" + NSRegularExpression.escapedPattern(for: trimmed) + "s?([^\\p{L}]|$)"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    /// Classifies a product using Open Food Facts tags and ingredient text.
    static func classify(labelsTags: [String], ingredientsTags: [String], analysisTags: [String],
                         ingredientsText: String, productName: String) -> (HalalStatus, [String]) {
        let texts = ingredientsTags + [ingredientsText, productName]
        let reasons = nonHalalReasons(in: texts)
        if !reasons.isEmpty { return (.potentiallyNonHalal, reasons) }
        if labelsTags.contains(where: { $0.lowercased().contains("halal") }) { return (.declaredHalal, []) }
        if containsMeat(in: texts) { return (.dependsOnOrigin, []) }
        let hasIngredients = !ingredientsTags.isEmpty || !ingredientsText.isEmpty
        if hasIngredients && analysisTags.contains("en:vegan") && !analysisTags.contains("en:maybe-vegan") {
            return (.plantBased, [])
        }
        return (.unknown, [])
    }
}
