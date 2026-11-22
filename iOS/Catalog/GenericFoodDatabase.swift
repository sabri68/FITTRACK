import Foundation

/// Built-in list of common generic foods (values per 100 g, rounded averages from public
/// food composition tables such as Ciqual/USDA). Pork products are intentionally absent.
enum GenericFoodDatabase {
    struct G {
        var id: String
        var name: String
        var kcal: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var serving: Double?
        var halal: HalalStatus
        var aliases: String

        var item: FoodItem {
            FoodItem(id: id, name: name, brand: "", barcode: "",
                     per100g: Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat),
                     servingGrams: serving, halal: halal, halalReasons: [], source: .generic)
        }
    }

    static let foods: [FoodItem] = entries.map(\.item)

    private static let searchIndex: [(FoodItem, String)] = entries.map {
        ($0.item, normalize($0.name + " " + $0.aliases))
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: FTFormat.locale)
            .replacingOccurrences(of: "œ", with: "oe")
    }

    /// Matches every word of the query against the food name and aliases.
    static func search(_ query: String) -> [FoodItem] {
        let words = normalize(query).split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        return searchIndex.filter { _, haystack in words.allSatisfy { haystack.contains($0) } }.map(\.0)
    }

    private static let entries: [G] = [
        G(id: "gen-000", name: "Blanc de poulet cuit", kcal: 165, protein: 31, carbs: 0, fat: 3.6, serving: 150, halal: .dependsOnOrigin, aliases: "chicken poulet volaille"),
        G(id: "gen-001", name: "Cuisse de poulet rôtie", kcal: 209, protein: 26, carbs: 0, fat: 10.9, serving: 150, halal: .dependsOnOrigin, aliases: "chicken poulet"),
        G(id: "gen-002", name: "Escalope de dinde cuite", kcal: 135, protein: 29, carbs: 0, fat: 1.7, serving: 150, halal: .dependsOnOrigin, aliases: "turkey dinde"),
        G(id: "gen-003", name: "Steak haché 5 % MG cuit", kcal: 171, protein: 26, carbs: 0, fat: 7.3, serving: 125, halal: .dependsOnOrigin, aliases: "beef boeuf bœuf steak hache burger"),
        G(id: "gen-004", name: "Steak haché 15 % MG cuit", kcal: 250, protein: 26, carbs: 0, fat: 16, serving: 125, halal: .dependsOnOrigin, aliases: "beef boeuf bœuf steak hache burger"),
        G(id: "gen-005", name: "Bœuf rumsteck grillé", kcal: 160, protein: 30, carbs: 0, fat: 4.5, serving: 150, halal: .dependsOnOrigin, aliases: "beef boeuf steak"),
        G(id: "gen-006", name: "Gigot d'agneau rôti", kcal: 230, protein: 26, carbs: 0, fat: 14, serving: 150, halal: .dependsOnOrigin, aliases: "lamb agneau"),
        G(id: "gen-007", name: "Kefta de bœuf grillée", kcal: 250, protein: 20, carbs: 3, fat: 17, serving: 120, halal: .dependsOnOrigin, aliases: "kefta boeuf viande hachee"),
        G(id: "gen-008", name: "Merguez de bœuf grillée", kcal: 290, protein: 16, carbs: 1, fat: 25, serving: 100, halal: .dependsOnOrigin, aliases: "merguez saucisse"),
        G(id: "gen-009", name: "Saumon cuit", kcal: 206, protein: 22, carbs: 0, fat: 13, serving: 130, halal: .naturallyHalal, aliases: "salmon saumon poisson"),
        G(id: "gen-010", name: "Thon au naturel (conserve)", kcal: 116, protein: 26, carbs: 0, fat: 1, serving: 100, halal: .naturallyHalal, aliases: "tuna thon poisson"),
        G(id: "gen-011", name: "Cabillaud cuit", kcal: 105, protein: 23, carbs: 0, fat: 0.9, serving: 150, halal: .naturallyHalal, aliases: "cod cabillaud poisson"),
        G(id: "gen-012", name: "Sardines à l'huile (égouttées)", kcal: 208, protein: 25, carbs: 0, fat: 12, serving: 85, halal: .naturallyHalal, aliases: "sardine poisson"),
        G(id: "gen-013", name: "Crevettes cuites", kcal: 99, protein: 24, carbs: 0.2, fat: 0.3, serving: 100, halal: .naturallyHalal, aliases: "shrimp crevette fruits de mer"),
        G(id: "gen-014", name: "Œuf entier", kcal: 143, protein: 12.6, carbs: 0.7, fat: 9.5, serving: 60, halal: .naturallyHalal, aliases: "egg oeuf oeufs œufs"),
        G(id: "gen-015", name: "Blanc d'œuf", kcal: 52, protein: 11, carbs: 0.7, fat: 0.2, serving: 33, halal: .naturallyHalal, aliases: "egg white blanc oeuf"),
        G(id: "gen-016", name: "Lait demi-écrémé", kcal: 46, protein: 3.3, carbs: 4.8, fat: 1.6, serving: 250, halal: .naturallyHalal, aliases: "milk lait"),
        G(id: "gen-017", name: "Yaourt nature", kcal: 61, protein: 3.8, carbs: 4.7, fat: 3.2, serving: 125, halal: .naturallyHalal, aliases: "yogurt yaourt"),
        G(id: "gen-018", name: "Skyr nature", kcal: 63, protein: 11, carbs: 4, fat: 0.2, serving: 150, halal: .naturallyHalal, aliases: "skyr yaourt proteine"),
        G(id: "gen-019", name: "Fromage blanc 0 %", kcal: 47, protein: 7.5, carbs: 4, fat: 0.2, serving: 100, halal: .naturallyHalal, aliases: "fromage blanc quark"),
        G(id: "gen-020", name: "Fromage blanc 3 %", kcal: 74, protein: 7.2, carbs: 3.8, fat: 3.2, serving: 100, halal: .naturallyHalal, aliases: "fromage blanc"),
        G(id: "gen-021", name: "Riz blanc cuit", kcal: 130, protein: 2.7, carbs: 28, fat: 0.3, serving: 150, halal: .naturallyHalal, aliases: "rice riz"),
        G(id: "gen-022", name: "Riz basmati cuit", kcal: 121, protein: 3.5, carbs: 25, fat: 0.4, serving: 150, halal: .naturallyHalal, aliases: "rice riz basmati"),
        G(id: "gen-023", name: "Riz complet cuit", kcal: 123, protein: 2.7, carbs: 25.6, fat: 1, serving: 150, halal: .naturallyHalal, aliases: "brown rice riz complet"),
        G(id: "gen-024", name: "Pâtes cuites", kcal: 157, protein: 5.8, carbs: 30.6, fat: 0.9, serving: 180, halal: .naturallyHalal, aliases: "pasta pates spaghetti"),
        G(id: "gen-025", name: "Pâtes complètes cuites", kcal: 149, protein: 6, carbs: 27, fat: 1.7, serving: 180, halal: .naturallyHalal, aliases: "pasta pates completes"),
        G(id: "gen-026", name: "Semoule de blé cuite", kcal: 112, protein: 3.8, carbs: 23, fat: 0.2, serving: 150, halal: .naturallyHalal, aliases: "couscous semoule"),
        G(id: "gen-027", name: "Quinoa cuit", kcal: 120, protein: 4.4, carbs: 21.3, fat: 1.9, serving: 150, halal: .naturallyHalal, aliases: "quinoa"),
        G(id: "gen-028", name: "Flocons d'avoine", kcal: 372, protein: 13.5, carbs: 58.7, fat: 7, serving: 50, halal: .naturallyHalal, aliases: "oats avoine flocons porridge"),
        G(id: "gen-029", name: "Pain complet", kcal: 247, protein: 9, carbs: 41, fat: 3.4, serving: 40, halal: .naturallyHalal, aliases: "bread pain complet"),
        G(id: "gen-030", name: "Baguette", kcal: 270, protein: 9, carbs: 55, fat: 1.2, serving: 50, halal: .naturallyHalal, aliases: "bread pain baguette"),
        G(id: "gen-031", name: "Pain de mie complet", kcal: 250, protein: 9, carbs: 43, fat: 4, serving: 30, halal: .naturallyHalal, aliases: "pain de mie"),
        G(id: "gen-032", name: "Pomme de terre cuite", kcal: 86, protein: 1.9, carbs: 18, fat: 0.1, serving: 200, halal: .naturallyHalal, aliases: "potato pomme de terre patate"),
        G(id: "gen-033", name: "Patate douce cuite", kcal: 90, protein: 2, carbs: 20.7, fat: 0.2, serving: 200, halal: .naturallyHalal, aliases: "sweet potato patate douce"),
        G(id: "gen-034", name: "Lentilles cuites", kcal: 116, protein: 9, carbs: 20, fat: 0.4, serving: 150, halal: .naturallyHalal, aliases: "lentils lentilles"),
        G(id: "gen-035", name: "Pois chiches cuits", kcal: 139, protein: 7.4, carbs: 21, fat: 2.6, serving: 150, halal: .naturallyHalal, aliases: "chickpeas pois chiches houmous"),
        G(id: "gen-036", name: "Haricots rouges cuits", kcal: 127, protein: 8.7, carbs: 22.8, fat: 0.5, serving: 150, halal: .naturallyHalal, aliases: "beans haricots rouges"),
        G(id: "gen-037", name: "Houmous", kcal: 250, protein: 7.8, carbs: 14, fat: 18, serving: 50, halal: .unknown, aliases: "hummus houmous"),
        G(id: "gen-038", name: "Tofu nature", kcal: 126, protein: 13, carbs: 2, fat: 7.5, serving: 100, halal: .naturallyHalal, aliases: "tofu soja"),
        G(id: "gen-039", name: "Brocoli cuit", kcal: 35, protein: 2.4, carbs: 7, fat: 0.4, serving: 150, halal: .naturallyHalal, aliases: "broccoli brocoli legume"),
        G(id: "gen-040", name: "Haricots verts cuits", kcal: 31, protein: 1.8, carbs: 7, fat: 0.2, serving: 150, halal: .naturallyHalal, aliases: "green beans haricots verts"),
        G(id: "gen-041", name: "Courgette cuite", kcal: 17, protein: 1.2, carbs: 3.1, fat: 0.3, serving: 150, halal: .naturallyHalal, aliases: "zucchini courgette"),
        G(id: "gen-042", name: "Épinards cuits", kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4, serving: 150, halal: .naturallyHalal, aliases: "spinach epinards"),
        G(id: "gen-043", name: "Carottes", kcal: 41, protein: 0.9, carbs: 9.6, fat: 0.2, serving: 100, halal: .naturallyHalal, aliases: "carrot carotte"),
        G(id: "gen-044", name: "Tomate", kcal: 18, protein: 0.9, carbs: 3.9, fat: 0.2, serving: 120, halal: .naturallyHalal, aliases: "tomato tomate"),
        G(id: "gen-045", name: "Concombre", kcal: 15, protein: 0.7, carbs: 3.6, fat: 0.1, serving: 100, halal: .naturallyHalal, aliases: "cucumber concombre"),
        G(id: "gen-046", name: "Salade verte", kcal: 15, protein: 1.4, carbs: 2.9, fat: 0.2, serving: 50, halal: .naturallyHalal, aliases: "salad salade laitue"),
        G(id: "gen-047", name: "Poivron", kcal: 31, protein: 1, carbs: 6, fat: 0.3, serving: 120, halal: .naturallyHalal, aliases: "pepper poivron"),
        G(id: "gen-048", name: "Avocat", kcal: 160, protein: 2, carbs: 8.5, fat: 14.7, serving: 100, halal: .naturallyHalal, aliases: "avocado avocat"),
        G(id: "gen-049", name: "Banane", kcal: 89, protein: 1.1, carbs: 22.8, fat: 0.3, serving: 120, halal: .naturallyHalal, aliases: "banana banane fruit"),
        G(id: "gen-050", name: "Pomme", kcal: 52, protein: 0.3, carbs: 13.8, fat: 0.2, serving: 150, halal: .naturallyHalal, aliases: "apple pomme fruit"),
        G(id: "gen-051", name: "Orange", kcal: 47, protein: 0.9, carbs: 11.8, fat: 0.1, serving: 150, halal: .naturallyHalal, aliases: "orange fruit"),
        G(id: "gen-052", name: "Fraises", kcal: 32, protein: 0.7, carbs: 7.7, fat: 0.3, serving: 150, halal: .naturallyHalal, aliases: "strawberry fraise fruit"),
        G(id: "gen-053", name: "Myrtilles", kcal: 57, protein: 0.7, carbs: 14.5, fat: 0.3, serving: 100, halal: .naturallyHalal, aliases: "blueberry myrtille fruit"),
        G(id: "gen-054", name: "Dattes", kcal: 282, protein: 2.5, carbs: 75, fat: 0.4, serving: 24, halal: .naturallyHalal, aliases: "dates dattes fruit"),
        G(id: "gen-055", name: "Raisin", kcal: 69, protein: 0.7, carbs: 18, fat: 0.2, serving: 150, halal: .naturallyHalal, aliases: "grapes raisin fruit"),
        G(id: "gen-056", name: "Amandes", kcal: 579, protein: 21, carbs: 21.6, fat: 49.9, serving: 30, halal: .naturallyHalal, aliases: "almonds amandes noix"),
        G(id: "gen-057", name: "Noix", kcal: 654, protein: 15, carbs: 13.7, fat: 65, serving: 30, halal: .naturallyHalal, aliases: "walnuts noix"),
        G(id: "gen-058", name: "Cacahuètes", kcal: 567, protein: 25.8, carbs: 16, fat: 49, serving: 30, halal: .naturallyHalal, aliases: "peanuts cacahuetes arachides"),
        G(id: "gen-059", name: "Beurre de cacahuète", kcal: 588, protein: 25, carbs: 20, fat: 50, serving: 15, halal: .unknown, aliases: "peanut butter beurre cacahuete"),
        G(id: "gen-060", name: "Huile d'olive", kcal: 884, protein: 0, carbs: 0, fat: 100, serving: 10, halal: .naturallyHalal, aliases: "olive oil huile olive"),
        G(id: "gen-061", name: "Beurre", kcal: 717, protein: 0.9, carbs: 0.1, fat: 81, serving: 10, halal: .naturallyHalal, aliases: "butter beurre"),
        G(id: "gen-062", name: "Miel", kcal: 304, protein: 0.3, carbs: 82, fat: 0, serving: 15, halal: .naturallyHalal, aliases: "honey miel"),
        G(id: "gen-063", name: "Chocolat noir 70 %", kcal: 598, protein: 7.8, carbs: 45.9, fat: 42.6, serving: 20, halal: .unknown, aliases: "dark chocolate chocolat noir"),
        G(id: "gen-064", name: "Whey protéine (poudre)", kcal: 380, protein: 78, carbs: 8, fat: 5, serving: 30, halal: .unknown, aliases: "whey proteine poudre shaker"),
        G(id: "gen-065", name: "Mozzarella", kcal: 280, protein: 22, carbs: 2.2, fat: 20, serving: 50, halal: .unknown, aliases: "mozzarella fromage"),
        G(id: "gen-066", name: "Emmental", kcal: 380, protein: 28, carbs: 0, fat: 30, serving: 30, halal: .unknown, aliases: "emmental fromage gruyere"),
        G(id: "gen-067", name: "Feta", kcal: 264, protein: 14, carbs: 4, fat: 21, serving: 30, halal: .unknown, aliases: "feta fromage"),
        G(id: "gen-068", name: "Jus d'orange", kcal: 45, protein: 0.7, carbs: 10.4, fat: 0.2, serving: 200, halal: .naturallyHalal, aliases: "orange juice jus"),
        G(id: "gen-069", name: "Café noir", kcal: 2, protein: 0.3, carbs: 0, fat: 0, serving: 200, halal: .naturallyHalal, aliases: "coffee cafe"),
        G(id: "gen-070", name: "Thé sans sucre", kcal: 1, protein: 0, carbs: 0.3, fat: 0, serving: 250, halal: .naturallyHalal, aliases: "tea the"),
    ]
}
