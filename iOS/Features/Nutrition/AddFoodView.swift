import SwiftUI
import PhotosUI

/// Adds a food with one of four methods: search, barcode, photo or manual entry.
struct AddFoodView: View {
    let meal: MealType
    let day: Date
    let halalOnly: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .search
    @State private var path = NavigationPath()

    enum Mode: String, CaseIterable, Identifiable {
        case search, scan, photo, manual
        var id: String { rawValue }
        var label: String {
            switch self {
            case .search: return "Rechercher"
            case .scan: return "Code-barres"
            case .photo: return "Photo"
            case .manual: return "Manuel"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Méthode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityIdentifier("addFood.mode")

                switch mode {
                case .search: FoodSearchPanel(halalOnly: halalOnly) { path.append($0) }
                case .scan: BarcodePanel { path.append($0) }
                case .photo: PhotoPanel(halalOnly: halalOnly) { path.append($0) }
                case .manual: ManualFoodPanel { path.append($0) }
                }
            }
            .navigationTitle("Ajouter · \(meal.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .navigationDestination(for: FoodItem.self) { food in
                FoodDetailView(food: food, initialMeal: meal, day: day) { dismiss() }
            }
        }
    }
}

// MARK: - Search

struct FoodSearchPanel: View {
    let halalOnly: Bool
    var onSelect: (FoodItem) -> Void
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        FoodResultsList(query: query, halalOnly: halalOnly, showRecents: true, onSelect: onSelect)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Poulet, riz, yaourt, marque…")
            .autocorrectionDisabled()
    }
}

/// Results from the built-in database and Open Food Facts, with halal filtering.
struct FoodResultsList: View {
    let query: String
    let halalOnly: Bool
    var showRecents = false
    var onSelect: (FoodItem) -> Void
    @Environment(AppModel.self) private var model
    @State private var remote: [FoodItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showExcluded = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let generic = GenericFoodDatabase.search(trimmed)
        let filtered = filter(remote)
        let visible = filtered.visible
        let excluded = filtered.excluded
        List {
            if trimmed.isEmpty && showRecents {
                let recents = model.data.recentFoods()
                if recents.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass", title: "Rechercher un aliment",
                                   message: "Aliments courants et produits du commerce (Open Food Facts).")
                } else {
                    Section("Récemment ajoutés") {
                        ForEach(recents) { food in row(food) }
                    }
                }
            }
            if !generic.isEmpty {
                Section("Aliments courants") {
                    ForEach(generic) { food in row(food) }
                }
            }
            if trimmed.count >= 2 {
                Section {
                    if isLoading {
                        HStack { ProgressView(); Text("Recherche…").foregroundStyle(.secondary) }
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "wifi.exclamationmark").foregroundStyle(.secondary)
                    } else if visible.isEmpty && excluded.isEmpty {
                        Text("Aucun produit trouvé.").foregroundStyle(.secondary)
                    }
                    ForEach(visible) { food in row(food) }
                    if showExcluded {
                        ForEach(excluded) { food in row(food) }
                    }
                } header: {
                    Text("Produits du commerce · Open Food Facts")
                } footer: {
                    if !excluded.isEmpty {
                        Button(showExcluded
                               ? "Masquer les \(excluded.count) produits potentiellement non halal"
                               : "\(excluded.count) produits masqués (ingrédients potentiellement non halal) · Afficher") {
                            showExcluded.toggle()
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .task(id: trimmed) { await searchRemote() }
    }

    private func filter(_ items: [FoodItem]) -> (visible: [FoodItem], excluded: [FoodItem]) {
        guard halalOnly else { return (items, []) }
        let visible = items.filter { $0.halal != .potentiallyNonHalal }
            .sorted { $0.halal.preferenceRank < $1.halal.preferenceRank }
        return (visible, items.filter { $0.halal == .potentiallyNonHalal })
    }

    private func row(_ food: FoodItem) -> some View {
        Button { onSelect(food) } label: { FoodItemRow(food: food) }
            .buttonStyle(.plain)
    }

    private func searchRemote() async {
        let q = trimmed
        remote = []
        errorMessage = nil
        guard q.count >= 2 else { isLoading = false; return }
        isLoading = true
        // Debounce typing (Open Food Facts asks clients to limit search requests).
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        do {
            let results = try await model.foodClient.search(q)
            guard !Task.isCancelled else { return }
            remote = results
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct FoodItemRow: View {
    let food: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: food.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: food.source == .generic ? "leaf.fill" : "cart.fill")
                    .foregroundStyle(Theme.accent.opacity(0.7))
            }
            .frame(width: 40, height: 40)
            .background(Theme.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).font(.subheadline.weight(.medium)).lineLimit(2)
                HStack(spacing: 6) {
                    Text(food.brand.isEmpty ? "\(FTFormat.kcal(food.per100g.kcal)) / 100 g" : "\(food.brand) · \(FTFormat.kcal(food.per100g.kcal)) / 100 g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HalalBadge(status: food.halal, compact: true)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Barcode

struct BarcodePanel: View {
    var onFound: (FoodItem) -> Void
    @Environment(AppModel.self) private var model
    @State private var manualCode = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var scannerID = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if BarcodeScannerView.isAvailable {
                    BarcodeScannerView { code in lookup(code) }
                        .id(scannerID)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .overlay(alignment: .bottom) {
                            Text("Placez le code-barres dans le cadre")
                                .font(.footnote.weight(.semibold))
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                        }
                } else {
                    Label(BarcodeScannerView.unavailableReason, systemImage: "barcode.viewfinder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .cardStyle()
                }
                if isLoading { ProgressView("Recherche du produit…") }
                if let message {
                    VStack(spacing: 8) {
                        Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if BarcodeScannerView.isAvailable {
                            Button("Scanner à nouveau") { self.message = nil; scannerID = UUID() }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saisir le code manuellement").font(.headline)
                    HStack {
                        TextField("Ex. 3017620422003", text: $manualCode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("barcode.manual")
                        Button("Chercher") { lookup(manualCode) }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(manualCode.filter(\.isNumber).count < 8)
                    }
                }
                .cardStyle()
            }
            .padding()
        }
    }

    private func lookup(_ code: String) {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        Task {
            defer { isLoading = false }
            do {
                let item = try await model.foodClient.product(barcode: code)
                onFound(item)
            } catch {
                message = "\(error.localizedDescription)\nCode : \(code). Vous pouvez saisir l'aliment manuellement."
            }
        }
    }
}

// MARK: - Photo

struct PhotoPanel: View {
    let halalOnly: Bool
    var onSelect: (FoodItem) -> Void
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var result: FoodPhotoRecognizer.Result?
    @State private var errorMessage: String?
    @State private var selectedQuery: String?

    var body: some View {
        VStack(spacing: 0) {
            if let selectedQuery {
                HStack {
                    Button {
                        self.selectedQuery = nil
                    } label: {
                        Label("Autres suggestions", systemImage: "chevron.left")
                    }
                    Spacer()
                    Text("« \(selectedQuery) »").font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                FoodResultsList(query: selectedQuery, halalOnly: halalOnly, onSelect: onSelect)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        preview
                        HStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Prendre une photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(!CameraPicker.isAvailable)
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Label("Choisir", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        if !CameraPicker.isAvailable {
                            Text("Appareil photo indisponible (simulateur) : choisissez une photo existante.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if isAnalyzing { ProgressView("Analyse de la photo sur l'appareil…") }
                        if let errorMessage {
                            Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                        }
                        if let result { candidates(result) }
                        Text("La reconnaissance est réalisée sur votre iPhone par le modèle d'analyse d'images d'Apple. Elle identifie le type d'aliment mais ne mesure pas la quantité : vous choisirez l'aliment exact et la portion à l'étape suivante.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { analyze($0) }.ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    analyze(img)
                } else {
                    errorMessage = "Impossible de charger cette photo."
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "camera.viewfinder").font(.system(size: 44)).foregroundStyle(Theme.accent)
                Text("Photographiez votre repas").font(.headline)
                Text("FitTrack vous propose les aliments reconnus.").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.subtleFill))
        }
    }

    @ViewBuilder private func candidates(_ result: FoodPhotoRecognizer.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if result.candidates.isEmpty {
                Text(result.looksLikeFood
                     ? "Un aliment semble présent mais le plat n'a pas été reconnu. Utilisez la recherche ou la saisie manuelle."
                     : "Aucun aliment reconnu sur cette photo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Aliments reconnus").font(.headline)
                ForEach(result.candidates) { c in
                    Button {
                        selectedQuery = c.query
                    } label: {
                        HStack {
                            Text(c.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(FTFormat.percent(c.confidence)) de confiance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.subtleFill))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func analyze(_ image: UIImage) {
        self.image = image
        result = nil
        errorMessage = nil
        isAnalyzing = true
        Task {
            defer { isAnalyzing = false }
            do {
                result = try await FoodPhotoRecognizer.recognize(image)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Manual

struct ManualFoodPanel: View {
    var onCreate: (FoodItem) -> Void
    @State private var name = ""
    @State private var brand = ""
    @State private var kcal: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var serving: Double = 100

    private var macros: Macros { Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat) }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && macros.isPlausiblePer100g && (kcal > 0 || protein + carbs + fat > 0)
    }

    var body: some View {
        Form {
            Section("Aliment") {
                TextField("Nom", text: $name).accessibilityIdentifier("manual.name")
                TextField("Marque (facultatif)", text: $brand)
            }
            Section {
                row("Énergie", $kcal, "kcal", id: "manual.kcal")
                row("Protéines", $protein, "g", id: "manual.protein")
                row("Glucides", $carbs, "g", id: "manual.carbs")
                row("Lipides", $fat, "g", id: "manual.fat")
            } header: {
                Text("Valeurs pour 100 g")
            } footer: {
                if !macros.isPlausiblePer100g {
                    Text("Valeurs incohérentes : pour 100 g, l'énergie ne peut dépasser 900 kcal et protéines + glucides + lipides 100 g.")
                        .foregroundStyle(.red)
                } else {
                    Text("Calcul de contrôle : \(FTFormat.kcal(protein * 4 + carbs * 4 + fat * 9)) d'après les macronutriments.")
                }
            }
            Section("Portion habituelle") {
                row("Portion", $serving, "g", id: "manual.serving")
            }
            Section {
                Button("Continuer") {
                    onCreate(FoodItem(id: "manual-\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces),
                                      brand: brand.trimmingCharacters(in: .whitespaces), barcode: "",
                                      per100g: macros, servingGrams: serving > 0 ? serving : nil,
                                      halal: .unknown, halalReasons: [], source: .manual))
                }
                .disabled(!isValid)
                .accessibilityIdentifier("manual.continue")
            }
        }
    }

    private func row(_ title: String, _ value: Binding<Double>, _ unit: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            DecimalField(title: "0", value: value, suffix: unit, width: 80, identifier: id)
        }
    }
}

// MARK: - Detail

struct FoodDetailView: View {
    let food: FoodItem
    let day: Date
    var onAdded: () -> Void
    @Environment(AppModel.self) private var model
    @State private var grams: Double
    @State private var meal: MealType

    init(food: FoodItem, initialMeal: MealType, day: Date, onAdded: @escaping () -> Void) {
        self.food = food
        self.day = day
        self.onAdded = onAdded
        _grams = State(initialValue: food.servingGrams ?? 100)
        _meal = State(initialValue: initialMeal)
    }

    var body: some View {
        let m = food.per100g.scaled(toGrams: grams)
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name).font(.title3.weight(.bold))
                    if !food.brand.isEmpty { Text(food.brand).foregroundStyle(.secondary) }
                    Text("Source : \(food.source.label)").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Section("Quantité") {
                HStack {
                    Text("Quantité")
                    Spacer()
                    DecimalField(title: "g", value: $grams, suffix: "g", width: 80, identifier: "food.grams")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let serving = food.servingGrams {
                            quick("1 portion (\(FTFormat.integer(serving)) g)", serving)
                        }
                        ForEach([50.0, 100, 150, 200, 250], id: \.self) { quick("\(FTFormat.integer($0)) g", $0) }
                    }
                }
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("Apports pour \(FTFormat.grams(grams))") {
                HStack {
                    macro("Calories", FTFormat.integer(m.kcal), "kcal", Theme.accent)
                    macro("Protéines", FTFormat.integer(m.protein), "g", Theme.protein)
                    macro("Glucides", FTFormat.integer(m.carbs), "g", Theme.carbs)
                    macro("Lipides", FTFormat.integer(m.fat), "g", Theme.fat)
                }
            }
            Section("Halal") {
                HalalBadge(status: food.halal)
                Text(food.halal.explanation).font(.footnote).foregroundStyle(.secondary)
                if !food.halalReasons.isEmpty {
                    Text("Détecté : \(food.halalReasons.joined(separator: ", "))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button {
                    model.addFood(food, grams: grams, meal: meal, day: day)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onAdded()
                } label: {
                    Label("Ajouter au journal", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(grams <= 0 || grams > 5000)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("food.add")
            }
        }
        .navigationTitle("Détails")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func quick(_ title: String, _ value: Double) -> some View {
        Button(title) { grams = value }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(grams == value ? Theme.accent : Theme.subtleFill))
            .foregroundStyle(grams == value ? .white : .primary)
            .buttonStyle(.plain)
    }

    private func macro(_ title: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
