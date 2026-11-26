import SwiftUI
import UIKit

/// Texte prêt à être partagé (Identifiable pour pouvoir ouvrir la feuille de partage).
struct TexteAPartager: Identifiable {
    let id = UUID()
    let texte: String
}

/// Récapitulatif d'un service, lisible directement dans un message (WhatsApp, SMS, mail...).
func texteRecap(_ service: Service) -> String {
    let morceaux = service.date_cloture.split(separator: " ")
    let entete: String
    if morceaux.count == 2 {
        entete = "EASY CB - Service du \(morceaux[0]) à \(morceaux[1])"
    } else {
        entete = "EASY CB - Service du \(service.date_cloture)"
    }

    var lignes = [entete, ""]
    for (i, centimes) in service.paiements.enumerated() {
        lignes.append("Paiement \(i + 1) : \(formater(centimes))")
    }
    lignes.append("")
    lignes.append("Nombre de paiements : \(service.paiements.count)")
    lignes.append("Total : \(formater(service.paiements.reduce(0, +)))")
    return lignes.joined(separator: "\n")
}

/// Feuille de partage iOS (WhatsApp, Messages, Mail, Notes, AirDrop...).
/// `termine` est appelé avec true si l'envoi a bien été fait.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var termine: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            termine?(completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
