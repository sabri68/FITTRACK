import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, quadriceps, hamstrings, glutes, calves, abs, traps

    var id: String { rawValue }
    var label: String {
        switch self {
        case .chest: return "Pectoraux"
        case .back: return "Dos"
        case .shoulders: return "Épaules"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Avant-bras"
        case .quadriceps: return "Quadriceps"
        case .hamstrings: return "Ischio-jambiers"
        case .glutes: return "Fessiers"
        case .calves: return "Mollets"
        case .abs: return "Abdominaux"
        case .traps: return "Trapèzes"
        }
    }
    var isLowerBody: Bool { [.quadriceps, .hamstrings, .glutes, .calves].contains(self) }
    var symbol: String {
        switch self {
        case .chest, .triceps, .shoulders: return "figure.strengthtraining.traditional"
        case .back, .traps: return "figure.rower"
        case .biceps, .forearms: return "dumbbell.fill"
        case .quadriceps, .glutes, .hamstrings: return "figure.strengthtraining.functional"
        case .calves: return "figure.step.training"
        case .abs: return "figure.core.training"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell
    var label: String {
        switch self {
        case .barbell: return "Barre"
        case .dumbbell: return "Haltères"
        case .machine: return "Machine"
        case .cable: return "Poulie"
        case .bodyweight: return "Poids du corps"
        case .kettlebell: return "Kettlebell"
        }
    }
}

/// An exercise from the built-in library.
struct Exercise: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var primary: MuscleGroup
    var secondary: [MuscleGroup]
    var equipment: Equipment
    var isCompound: Bool
    var summary: String
    var steps: [String]
    var tips: [String]

    var isLowerBody: Bool { primary.isLowerBody }
    var symbol: String { primary.symbol }
    /// Search query for a video demonstration (visual reference).
    var demoSearchURL: URL? {
        var comps = URLComponents(string: "https://www.youtube.com/results")
        comps?.queryItems = [URLQueryItem(name: "search_query", value: "\(name) technique exécution")]
        return comps?.url
    }
}

enum ExerciseCatalog {
    static func exercise(id: String) -> Exercise? { byId[id] }

    static let byId: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func search(_ query: String, muscle: MuscleGroup? = nil) -> [Exercise] {
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: FTFormat.locale)
            .trimmingCharacters(in: .whitespaces)
        return all.filter { ex in
            (muscle == nil || ex.primary == muscle || ex.secondary.contains(muscle!)) &&
            (q.isEmpty || ex.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: FTFormat.locale).contains(q)
             || ex.primary.label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: FTFormat.locale).contains(q))
        }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // swiftlint:disable line_length
    static let all: [Exercise] = [
        // MARK: Chest
        Exercise(id: "bench_press", name: "Développé couché barre", primary: .chest, secondary: [.triceps, .shoulders], equipment: .barbell, isCompound: true,
                 summary: "L'exercice de base pour développer la force et le volume des pectoraux.",
                 steps: ["Allongez-vous sur le banc, les yeux sous la barre, pieds à plat au sol.", "Saisissez la barre un peu plus large que les épaules, serrez les omoplates.", "Descendez la barre de façon contrôlée jusqu'au bas des pectoraux.", "Poussez la barre vers le haut en expirant, sans décoller les fesses du banc."],
                 tips: ["Gardez les coudes à environ 45° du buste.", "Utilisez un partenaire ou des sécurités pour les charges lourdes."]),
        Exercise(id: "incline_db_press", name: "Développé incliné haltères", primary: .chest, secondary: [.shoulders, .triceps], equipment: .dumbbell, isCompound: true,
                 summary: "Cible le haut des pectoraux avec une grande amplitude de mouvement.",
                 steps: ["Réglez le banc entre 30° et 45°.", "Haltères au niveau de la poitrine, paumes vers l'avant.", "Poussez les haltères vers le haut en les rapprochant légèrement.", "Redescendez lentement jusqu'à sentir l'étirement des pectoraux."],
                 tips: ["Ne verrouillez pas complètement les coudes en haut.", "Gardez les omoplates serrées contre le banc."]),
        Exercise(id: "db_bench_press", name: "Développé couché haltères", primary: .chest, secondary: [.triceps, .shoulders], equipment: .dumbbell, isCompound: true,
                 summary: "Variante aux haltères, plus libre et plus sûre pour débuter.",
                 steps: ["Allongé sur un banc plat, haltères au-dessus de la poitrine.", "Descendez les haltères sur les côtés de la poitrine.", "Poussez vers le haut en expirant."],
                 tips: ["Contrôlez la descente sur 2 à 3 secondes."]),
        Exercise(id: "cable_fly", name: "Écarté à la poulie vis-à-vis", primary: .chest, secondary: [.shoulders], equipment: .cable, isCompound: false,
                 summary: "Isolation des pectoraux avec une tension constante.",
                 steps: ["Placez les poulies à hauteur d'épaules, une poignée dans chaque main.", "Avancez d'un pas, bras légèrement fléchis.", "Ramenez les mains l'une vers l'autre devant la poitrine.", "Revenez lentement en gardant la tension."],
                 tips: ["Gardez la même flexion des coudes pendant tout le mouvement."]),
        Exercise(id: "push_up", name: "Pompes", primary: .chest, secondary: [.triceps, .shoulders, .abs], equipment: .bodyweight, isCompound: true,
                 summary: "Exercice au poids du corps pour les pectoraux et le gainage.",
                 steps: ["Mains au sol un peu plus larges que les épaules, corps aligné.", "Descendez la poitrine près du sol.", "Poussez pour revenir bras tendus."],
                 tips: ["Gardez les abdominaux et les fessiers contractés."]),
        Exercise(id: "dips", name: "Dips assistés", primary: .chest, secondary: [.triceps, .shoulders], equipment: .machine, isCompound: true,
                 summary: "Travaille le bas des pectoraux et les triceps.",
                 steps: ["Placez-vous sur la machine d'assistance, bras tendus.", "Penchez légèrement le buste vers l'avant.", "Descendez jusqu'à ce que les épaules soient au niveau des coudes.", "Remontez en poussant sur les barres."],
                 tips: ["Diminuez l'assistance au fil des semaines."]),
        // MARK: Back
        Exercise(id: "barbell_row", name: "Rowing barre", primary: .back, secondary: [.biceps, .traps], equipment: .barbell, isCompound: true,
                 summary: "Développe l'épaisseur du dos.",
                 steps: ["Pieds largeur de hanches, saisissez la barre en pronation.", "Penchez le buste à environ 45°, dos plat.", "Tirez la barre vers le nombril en serrant les omoplates.", "Redescendez de façon contrôlée."],
                 tips: ["Ne donnez pas d'élan avec le buste.", "Gardez le dos neutre en permanence."]),
        Exercise(id: "lat_pulldown", name: "Tirage vertical", primary: .back, secondary: [.biceps], equipment: .cable, isCompound: true,
                 summary: "Développe la largeur du dos (grands dorsaux).",
                 steps: ["Asseyez-vous, cuisses bloquées sous les boudins.", "Saisissez la barre plus large que les épaules.", "Tirez la barre vers le haut de la poitrine en abaissant les coudes.", "Remontez lentement bras tendus."],
                 tips: ["Pensez à tirer avec les coudes, pas avec les mains."]),
        Exercise(id: "assisted_pullup", name: "Tractions assistées", primary: .back, secondary: [.biceps, .forearms], equipment: .machine, isCompound: true,
                 summary: "Progression vers les tractions complètes.",
                 steps: ["Agenouillez-vous sur la plateforme d'assistance.", "Saisissez la barre en pronation.", "Tirez jusqu'à ce que le menton dépasse la barre.", "Redescendez bras tendus."],
                 tips: ["Réduisez l'assistance progressivement."]),
        Exercise(id: "one_arm_db_row", name: "Rowing haltère unilatéral", primary: .back, secondary: [.biceps], equipment: .dumbbell, isCompound: true,
                 summary: "Travail unilatéral du dos pour corriger les déséquilibres.",
                 steps: ["Un genou et une main sur le banc, dos plat.", "Tirez l'haltère vers la hanche.", "Redescendez en étirant le dos."],
                 tips: ["Évitez la rotation du buste."]),
        Exercise(id: "seated_cable_row", name: "Tirage horizontal assis", primary: .back, secondary: [.biceps, .traps], equipment: .cable, isCompound: true,
                 summary: "Renforce le milieu du dos.",
                 steps: ["Assis, pieds sur les cales, dos droit.", "Tirez la poignée vers le ventre.", "Serrez les omoplates puis revenez lentement."],
                 tips: ["Ne vous penchez pas en arrière pour tirer."]),
        Exercise(id: "face_pull", name: "Face pull", primary: .shoulders, secondary: [.traps, .back], equipment: .cable, isCompound: false,
                 summary: "Renforce l'arrière des épaules et améliore la posture.",
                 steps: ["Réglez la poulie à hauteur du visage avec une corde.", "Tirez la corde vers le visage en écartant les mains.", "Marquez une pause puis revenez lentement."],
                 tips: ["Gardez les coudes hauts."]),
        Exercise(id: "deadlift", name: "Soulevé de terre", primary: .back, secondary: [.glutes, .hamstrings, .traps, .forearms], equipment: .barbell, isCompound: true,
                 summary: "Exercice complet de force pour toute la chaîne postérieure.",
                 steps: ["Pieds sous la barre, largeur de hanches.", "Saisissez la barre, dos plat, poitrine sortie.", "Poussez dans le sol pour vous redresser, barre près des jambes.", "Redescendez en reculant les hanches."],
                 tips: ["Apprenez la technique avec une charge légère.", "N'arrondissez jamais le bas du dos."]),
        // MARK: Shoulders
        Exercise(id: "overhead_press", name: "Développé militaire barre", primary: .shoulders, secondary: [.triceps, .traps], equipment: .barbell, isCompound: true,
                 summary: "Développe la force et le volume des épaules.",
                 steps: ["Debout, barre au niveau des clavicules.", "Gainez les abdominaux et les fessiers.", "Poussez la barre au-dessus de la tête.", "Redescendez de façon contrôlée."],
                 tips: ["Ne cambrez pas le bas du dos."]),
        Exercise(id: "db_shoulder_press", name: "Développé épaules haltères", primary: .shoulders, secondary: [.triceps], equipment: .dumbbell, isCompound: true,
                 summary: "Variante assise aux haltères, plus stable pour débuter.",
                 steps: ["Assis sur un banc à dossier droit.", "Haltères à hauteur d'épaules, paumes vers l'avant.", "Poussez vers le haut puis redescendez lentement."],
                 tips: ["Gardez le dos collé au dossier."]),
        Exercise(id: "lateral_raise", name: "Élévations latérales", primary: .shoulders, secondary: [], equipment: .dumbbell, isCompound: false,
                 summary: "Isolation de la partie latérale des épaules pour les élargir.",
                 steps: ["Debout, haltères le long du corps.", "Montez les bras sur les côtés jusqu'à l'horizontale.", "Redescendez lentement."],
                 tips: ["Utilisez une charge légère et évitez l'élan."]),
        Exercise(id: "rear_delt_fly", name: "Oiseau haltères", primary: .shoulders, secondary: [.traps], equipment: .dumbbell, isCompound: false,
                 summary: "Isolation de l'arrière des épaules.",
                 steps: ["Buste penché, dos plat, haltères sous la poitrine.", "Écartez les bras sur les côtés.", "Redescendez lentement."],
                 tips: ["Pensez à écarter, pas à tirer."]),
        Exercise(id: "shrug", name: "Shrug haltères", primary: .traps, secondary: [.forearms], equipment: .dumbbell, isCompound: false,
                 summary: "Développe les trapèzes.",
                 steps: ["Debout, haltères le long du corps.", "Haussez les épaules vers les oreilles.", "Marquez une pause puis redescendez."],
                 tips: ["Ne faites pas de rotation des épaules."]),
        // MARK: Arms
        Exercise(id: "barbell_curl", name: "Curl barre", primary: .biceps, secondary: [.forearms], equipment: .barbell, isCompound: false,
                 summary: "Exercice de base pour les biceps.",
                 steps: ["Debout, barre en supination, bras tendus.", "Fléchissez les coudes pour monter la barre.", "Redescendez lentement."],
                 tips: ["Gardez les coudes fixes contre le corps."]),
        Exercise(id: "db_curl", name: "Curl haltères", primary: .biceps, secondary: [.forearms], equipment: .dumbbell, isCompound: false,
                 summary: "Travail des biceps bras par bras ou simultané.",
                 steps: ["Debout, haltères le long du corps.", "Montez les haltères en tournant les paumes vers le haut.", "Redescendez lentement."],
                 tips: ["Évitez de balancer le buste."]),
        Exercise(id: "hammer_curl", name: "Curl marteau", primary: .biceps, secondary: [.forearms], equipment: .dumbbell, isCompound: false,
                 summary: "Cible le brachial et les avant-bras.",
                 steps: ["Haltères en prise neutre (pouces vers le haut).", "Fléchissez les coudes.", "Redescendez lentement."],
                 tips: ["Gardez les poignets neutres."]),
        Exercise(id: "triceps_pushdown", name: "Extension triceps à la poulie", primary: .triceps, secondary: [], equipment: .cable, isCompound: false,
                 summary: "Isolation des triceps avec une tension constante.",
                 steps: ["Face à la poulie haute, saisissez la barre ou la corde.", "Coudes collés au corps, tendez les bras vers le bas.", "Remontez lentement jusqu'à 90°."],
                 tips: ["Seuls les avant-bras bougent."]),
        Exercise(id: "skull_crusher", name: "Barre au front", primary: .triceps, secondary: [], equipment: .barbell, isCompound: false,
                 summary: "Développe la longue portion des triceps.",
                 steps: ["Allongé, barre EZ bras tendus au-dessus du front.", "Fléchissez les coudes pour descendre la barre vers le front.", "Tendez les bras pour remonter."],
                 tips: ["Gardez les coudes orientés vers le plafond."]),
        Exercise(id: "overhead_triceps_ext", name: "Extension triceps au-dessus de la tête", primary: .triceps, secondary: [], equipment: .dumbbell, isCompound: false,
                 summary: "Étire et renforce les triceps.",
                 steps: ["Assis, un haltère tenu à deux mains au-dessus de la tête.", "Descendez l'haltère derrière la tête.", "Tendez les bras pour remonter."],
                 tips: ["Gardez les coudes proches de la tête."]),
        // MARK: Legs
        Exercise(id: "back_squat", name: "Squat barre", primary: .quadriceps, secondary: [.glutes, .hamstrings, .abs], equipment: .barbell, isCompound: true,
                 summary: "Le roi des exercices pour les jambes.",
                 steps: ["Barre sur les trapèzes, pieds largeur d'épaules.", "Descendez en poussant les hanches en arrière et en fléchissant les genoux.", "Descendez au moins jusqu'à ce que les cuisses soient parallèles au sol.", "Remontez en poussant dans les talons."],
                 tips: ["Les genoux suivent la direction des pieds.", "Gardez la poitrine haute."]),
        Exercise(id: "goblet_squat", name: "Goblet squat", primary: .quadriceps, secondary: [.glutes, .abs], equipment: .dumbbell, isCompound: true,
                 summary: "Variante de squat idéale pour apprendre la technique.",
                 steps: ["Tenez un haltère contre la poitrine.", "Descendez en squat, coudes entre les genoux.", "Remontez en poussant dans les talons."],
                 tips: ["Gardez le buste le plus droit possible."]),
        Exercise(id: "leg_press", name: "Presse à cuisses", primary: .quadriceps, secondary: [.glutes, .hamstrings], equipment: .machine, isCompound: true,
                 summary: "Permet de charger les jambes en sécurité.",
                 steps: ["Dos bien calé, pieds largeur d'épaules sur la plateforme.", "Déverrouillez et descendez jusqu'à 90° aux genoux.", "Poussez sans verrouiller les genoux."],
                 tips: ["Ne décollez pas le bas du dos du dossier."]),
        Exercise(id: "romanian_deadlift", name: "Soulevé de terre roumain", primary: .hamstrings, secondary: [.glutes, .back], equipment: .barbell, isCompound: true,
                 summary: "Cible les ischio-jambiers et les fessiers.",
                 steps: ["Debout, barre en main, genoux légèrement fléchis.", "Poussez les hanches en arrière en descendant la barre le long des jambes.", "Descendez jusqu'à l'étirement des ischio-jambiers.", "Revenez en contractant les fessiers."],
                 tips: ["Gardez le dos plat et la barre près des jambes."]),
        Exercise(id: "leg_curl", name: "Leg curl allongé", primary: .hamstrings, secondary: [.calves], equipment: .machine, isCompound: false,
                 summary: "Isolation des ischio-jambiers.",
                 steps: ["Allongé sur la machine, boudin au-dessus des talons.", "Fléchissez les jambes vers les fessiers.", "Redescendez lentement."],
                 tips: ["Gardez les hanches plaquées contre le banc."]),
        Exercise(id: "seated_leg_curl", name: "Leg curl assis", primary: .hamstrings, secondary: [], equipment: .machine, isCompound: false,
                 summary: "Isolation des ischio-jambiers en position assise.",
                 steps: ["Assis, boudin derrière les chevilles.", "Fléchissez les genoux au maximum.", "Revenez lentement."],
                 tips: ["Contrôlez la phase de retour."]),
        Exercise(id: "leg_extension", name: "Leg extension", primary: .quadriceps, secondary: [], equipment: .machine, isCompound: false,
                 summary: "Isolation des quadriceps.",
                 steps: ["Assis, boudin devant les chevilles.", "Tendez les jambes.", "Redescendez lentement."],
                 tips: ["Marquez une pause en haut du mouvement."]),
        Exercise(id: "walking_lunge", name: "Fentes marchées haltères", primary: .quadriceps, secondary: [.glutes, .hamstrings], equipment: .dumbbell, isCompound: true,
                 summary: "Travail unilatéral des jambes et de l'équilibre.",
                 steps: ["Haltères en main, faites un grand pas en avant.", "Descendez jusqu'à ce que le genou arrière frôle le sol.", "Poussez pour enchaîner avec l'autre jambe."],
                 tips: ["Comptez les répétitions par jambe."]),
        Exercise(id: "hip_thrust", name: "Hip thrust", primary: .glutes, secondary: [.hamstrings], equipment: .barbell, isCompound: true,
                 summary: "Le meilleur exercice pour les fessiers.",
                 steps: ["Haut du dos appuyé sur un banc, barre sur les hanches.", "Poussez les hanches vers le haut.", "Contractez les fessiers en haut puis redescendez."],
                 tips: ["Utilisez un coussin pour protéger les hanches."]),
        Exercise(id: "standing_calf_raise", name: "Mollets debout", primary: .calves, secondary: [], equipment: .machine, isCompound: false,
                 summary: "Développe les mollets (gastrocnémiens).",
                 steps: ["Debout sur la machine, avant des pieds sur la marche.", "Montez sur la pointe des pieds.", "Redescendez en étirant les mollets."],
                 tips: ["Faites une pause en bas pour éviter le rebond."]),
        Exercise(id: "seated_calf_raise", name: "Mollets assis", primary: .calves, secondary: [], equipment: .machine, isCompound: false,
                 summary: "Cible le soléaire.",
                 steps: ["Assis, genoux sous le boudin.", "Montez sur la pointe des pieds.", "Redescendez lentement."],
                 tips: ["Amplitude complète à chaque répétition."]),
        // MARK: Core
        Exercise(id: "cable_crunch", name: "Crunch à la poulie", primary: .abs, secondary: [], equipment: .cable, isCompound: false,
                 summary: "Renforce les abdominaux avec une charge progressive.",
                 steps: ["À genoux face à la poulie haute, corde derrière la tête.", "Enroulez le buste vers le bas.", "Revenez lentement."],
                 tips: ["Le mouvement vient des abdominaux, pas des bras."]),
        Exercise(id: "hanging_leg_raise", name: "Relevés de jambes suspendu", primary: .abs, secondary: [.forearms], equipment: .bodyweight, isCompound: false,
                 summary: "Cible le bas des abdominaux.",
                 steps: ["Suspendu à une barre, bras tendus.", "Montez les genoux ou les jambes vers la poitrine.", "Redescendez sans balancer."],
                 tips: ["Commencez genoux fléchis si c'est trop difficile."]),
        Exercise(id: "plank", name: "Gainage (répétitions de 10 s)", primary: .abs, secondary: [.shoulders], equipment: .bodyweight, isCompound: false,
                 summary: "Renforce la sangle abdominale. Une répétition = 10 secondes tenues.",
                 steps: ["En appui sur les avant-bras et les pointes de pieds.", "Alignez épaules, hanches et chevilles.", "Tenez la position en respirant normalement."],
                 tips: ["Ne laissez pas les hanches s'affaisser."]),
    ]
    // swiftlint:enable line_length
}
