import Foundation
import SwiftUI

// Même format de données que la version Android (journal_cb.json, montants en centimes).
struct Service: Codable, Identifiable {
    var id = UUID()
    var date_cloture: String
    var paiements: [Int]

    enum CodingKeys: String, CodingKey {
        case date_cloture, paiements
    }
}

struct Donnees: Codable {
    var service_en_cours: [Int] = []
    var anciens_services: [Service] = []
}

enum Couleurs {
    static let nuit = Color(red: 0.035, green: 0.07, blue: 0.13)
    static let bouton = Color(red: 0.16, green: 0.28, blue: 0.4)
    static let paiement = Color(red: 0.12, green: 0.19, blue: 0.28)
    static let turquoise = Color(red: 0.05, green: 0.65, blue: 0.62)
    static let rouge = Color(red: 0.55, green: 0.16, blue: 0.20)
    static let accent = Color(red: 0.1, green: 0.85, blue: 0.8)
}

func formater(_ centimes: Int) -> String {
    "\(centimes / 100),\(String(format: "%02d", centimes % 100)) €"
}

/// Convertit un texte saisi ("12,50") en centimes. Retourne nil si invalide ou <= 0.
func parserMontant(_ texte: String) -> Int? {
    let propre = texte
        .replacingOccurrences(of: ",", with: ".")
        .trimmingCharacters(in: .whitespaces)
    guard let valeur = Double(propre) else { return nil }
    let centimes = Int((valeur * 100).rounded())
    return centimes > 0 ? centimes : nil
}

/// Nettoie un texte dicté : "douze euros 50" -> "12.50", "12 virgule 5" -> "12.5"
func normaliserDictee(_ brut: String) -> String {
    var s = brut.lowercased()
    s = s.replacingOccurrences(
        of: #"(\d+)\s*euros?\s*(\d+)"#,
        with: "$1.$2",
        options: .regularExpression
    )
    s = s.replacingOccurrences(of: "virgule", with: ".")
    s = s.replacingOccurrences(of: "point", with: ".")
    s = s.replacingOccurrences(of: "euros", with: "")
    s = s.replacingOccurrences(of: "euro", with: "")
    s = s.replacingOccurrences(of: "€", with: "")
    s = s.replacingOccurrences(of: ",", with: ".")
    return String(s.filter { $0.isNumber || $0 == "." })
}

final class Store: ObservableObject {
    @Published var donnees = Donnees()

    private var url: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("journal_cb.json")
    }

    init() {
        if let data = try? Data(contentsOf: url),
           let d = try? JSONDecoder().decode(Donnees.self, from: data) {
            donnees = d
        }
    }

    private func sauvegarder() {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        if let data = try? encodeur.encode(donnees) {
            try? data.write(to: url, options: .atomic)
        }
    }

    var paiements: [Int] { donnees.service_en_cours }
    var total: Int { paiements.reduce(0, +) }

    func ajouter(_ centimes: Int) {
        donnees.service_en_cours.append(centimes)
        sauvegarder()
    }

    func modifier(_ indice: Int, centimes: Int) {
        guard donnees.service_en_cours.indices.contains(indice) else { return }
        donnees.service_en_cours[indice] = centimes
        sauvegarder()
    }

    func supprimerPaiement(_ indice: Int) {
        guard donnees.service_en_cours.indices.contains(indice) else { return }
        donnees.service_en_cours.remove(at: indice)
        sauvegarder()
    }

    /// Archive le service en cours. Retourne false s'il n'y a rien à archiver.
    func cloturer() -> Bool {
        guard !donnees.service_en_cours.isEmpty else { return false }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        donnees.anciens_services.append(
            Service(date_cloture: f.string(from: Date()), paiements: donnees.service_en_cours)
        )
        donnees.service_en_cours = []
        sauvegarder()
        return true
    }

    func supprimerService(_ indice: Int) {
        guard donnees.anciens_services.indices.contains(indice) else { return }
        donnees.anciens_services.remove(at: indice)
        sauvegarder()
    }
}
