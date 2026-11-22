import Foundation

/// Client for the free Open Food Facts database (https://world.openfoodfacts.org).
/// No API key is required; the API terms ask for an identifying User-Agent.
struct OpenFoodFactsClient {
    enum OFFError: LocalizedError {
        case notFound
        case network(String)
        case invalidResponse
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .notFound: return "Produit introuvable dans Open Food Facts."
            case .network(let msg): return "Connexion impossible à Open Food Facts : \(msg)"
            case .invalidResponse: return "Réponse inattendue d'Open Food Facts."
            case .rateLimited: return "Trop de recherches en peu de temps. Réessayez dans une minute."
            }
        }
    }

    private static let fields = [
        "code", "product_name", "product_name_fr", "generic_name_fr", "brands", "nutriments", "labels_tags",
        "ingredients_tags", "ingredients_analysis_tags", "ingredients_text_fr", "ingredients_text",
        "serving_quantity", "image_front_small_url",
    ].joined(separator: ",")

    var session: URLSession = .shared

    func product(barcode: String) async throws -> FoodItem {
        let code = barcode.filter(\.isNumber)
        guard !code.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code)?fields=\(Self.fields)&lc=fr")
        else { throw OFFError.notFound }
        let json = try await fetchJSON(url)
        guard (json["status"] as? Int) == 1, let product = json["product"] as? [String: Any],
              let item = Self.parse(product, source: .barcode, fallbackCode: code) else {
            throw OFFError.notFound
        }
        return item
    }

    func search(_ query: String, page: Int = 1) async throws -> [FoodItem] {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        comps.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "30"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "lc", value: "fr"),
            URLQueryItem(name: "cc", value: "fr"),
            URLQueryItem(name: "fields", value: Self.fields),
        ]
        guard let url = comps.url else { throw OFFError.invalidResponse }
        let json = try await fetchJSON(url)
        let products = json["products"] as? [[String: Any]] ?? []
        return products.compactMap { Self.parse($0, source: .openFoodFacts, fallbackCode: nil) }
    }

    private func fetchJSON(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw OFFError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw OFFError.notFound }
            if http.statusCode == 429 { throw OFFError.rateLimited }
            guard (200..<300).contains(http.statusCode) else { throw OFFError.network("code \(http.statusCode)") }
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OFFError.invalidResponse
        }
        return json
    }

    // MARK: Parsing

    static func number(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return FTFormat.parseDecimal(s)
        default: return nil
        }
    }

    /// Converts an Open Food Facts product into a `FoodItem`. Returns nil when nutrition data is missing.
    static func parse(_ p: [String: Any], source: FoodSource, fallbackCode: String?) -> FoodItem? {
        let nutriments = p["nutriments"] as? [String: Any] ?? [:]
        var kcal = number(nutriments["energy-kcal_100g"])
        if kcal == nil, let kj = number(nutriments["energy_100g"]) ?? number(nutriments["energy-kj_100g"]) {
            kcal = kj / 4.184
        }
        guard let energy = kcal else { return nil }
        let macros = Macros(kcal: energy,
                            protein: number(nutriments["proteins_100g"]) ?? 0,
                            carbs: number(nutriments["carbohydrates_100g"]) ?? 0,
                            fat: number(nutriments["fat_100g"]) ?? 0)
        guard macros.kcal >= 0, macros.kcal < 1000 else { return nil }

        let name = [p["product_name_fr"], p["product_name"], p["generic_name_fr"]]
            .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Produit sans nom"
        let brand = (p["brands"] as? String)?.split(separator: ",").first.map {
            String($0).trimmingCharacters(in: .whitespaces)
        } ?? ""
        let code = (p["code"] as? String) ?? fallbackCode ?? ""
        let ingredientsText = (p["ingredients_text_fr"] as? String) ?? (p["ingredients_text"] as? String) ?? ""
        let (halal, reasons) = HalalAnalyzer.classify(
            labelsTags: p["labels_tags"] as? [String] ?? [],
            ingredientsTags: p["ingredients_tags"] as? [String] ?? [],
            analysisTags: p["ingredients_analysis_tags"] as? [String] ?? [],
            ingredientsText: ingredientsText,
            productName: name)
        let serving = number(p["serving_quantity"]).flatMap { $0 > 0 && $0 < 2000 ? $0 : nil }
        let image = (p["image_front_small_url"] as? String).flatMap(URL.init(string:))
        return FoodItem(id: code.isEmpty ? UUID().uuidString : code, name: name, brand: brand, barcode: code,
                        per100g: macros, servingGrams: serving, halal: halal, halalReasons: reasons,
                        source: source, imageURL: image)
    }
}
