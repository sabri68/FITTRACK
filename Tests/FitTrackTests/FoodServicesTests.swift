import XCTest
@testable import FitTrack

final class OpenFoodFactsParsingTests: XCTestCase {
    private func product(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testParsesNutrimentsAndDeclaredHalal() throws {
        let p = try product("""
        {"code":"3250390000000","product_name_fr":"Nuggets de poulet","brands":"Marque A, Marque B",
         "nutriments":{"energy-kcal_100g":245,"proteins_100g":"14,5","carbohydrates_100g":18,"fat_100g":12.3},
         "labels_tags":["en:halal"],"ingredients_tags":["en:chicken","en:wheat-flour"],"serving_quantity":"120"}
        """)
        let item = try XCTUnwrap(OpenFoodFactsClient.parse(p, source: .barcode, fallbackCode: nil))
        XCTAssertEqual(item.name, "Nuggets de poulet")
        XCTAssertEqual(item.brand, "Marque A")
        XCTAssertEqual(item.per100g.kcal, 245)
        XCTAssertEqual(item.per100g.protein, 14.5)
        XCTAssertEqual(item.servingGrams, 120)
        XCTAssertEqual(item.halal, .declaredHalal)
        XCTAssertEqual(item.barcode, "3250390000000")
    }

    func testConvertsKilojoulesAndFlagsPork() throws {
        let p = try product("""
        {"code":"1","product_name":"Saucisson sec","nutriments":{"energy_100g":1674,"proteins_100g":25,"fat_100g":32},
         "ingredients_text_fr":"viande de porc, sel, dextrose"}
        """)
        let item = try XCTUnwrap(OpenFoodFactsClient.parse(p, source: .openFoodFacts, fallbackCode: nil))
        XCTAssertEqual(item.per100g.kcal, 400, accuracy: 0.5)
        XCTAssertEqual(item.halal, .potentiallyNonHalal)
        XCTAssertTrue(item.halalReasons.contains("porc"))
    }

    func testRejectsProductWithoutEnergy() throws {
        let p = try product("""
        {"code":"2","product_name":"Inconnu","nutriments":{}}
        """)
        XCTAssertNil(OpenFoodFactsClient.parse(p, source: .openFoodFacts, fallbackCode: nil))
    }
}

final class FoodPhotoMappingTests: XCTestCase {
    func testMapsClassifierLabelsToFrenchFoods() {
        let candidates = FoodLabelMap.candidates(from: [
            (identifier: "food", confidence: 0.9),
            (identifier: "pasta", confidence: 0.6),
            (identifier: "spaghetti", confidence: 0.5),
            (identifier: "tomato", confidence: 0.2),
            (identifier: "dog", confidence: 0.4),
            (identifier: "salad", confidence: 0.01),
        ])
        XCTAssertEqual(candidates.map(\.name), ["Pâtes", "Spaghetti", "Tomate"])
        XCTAssertFalse(candidates.contains { $0.label == "food" }, "Generic labels are not proposed as dishes")
    }

    func testLooksLikeFood() {
        XCTAssertTrue(FoodLabelMap.looksLikeFood([(identifier: "food", confidence: 0.7)]))
        XCTAssertFalse(FoodLabelMap.looksLikeFood([(identifier: "dog", confidence: 0.9)]))
    }

    func testEveryMappedQueryIsNonEmpty() {
        for (label, entry) in FoodLabelMap.entries {
            XCTAssertFalse(entry.name.isEmpty, label)
            XCTAssertFalse(entry.query.isEmpty, label)
        }
    }
}
