import SwiftUI

/// Durée (en secondes) avant l'ajout automatique du paiement si on ne touche à rien.
let delaiValidation = 5

/// Numéro de version affiché en bas de l'écran (pour vérifier quelle version est installée).
let versionApp = "1.4"

struct BoutonCB: ButtonStyle {
    var couleur: Color
    var taille: CGFloat = 17
    var gras = false
    var hauteur: CGFloat = 55

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: taille, weight: gras ? .bold : .regular))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: hauteur)
            .background(couleur.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContentView: View {
    @StateObject private var store = Store()
    @StateObject private var dictee = DicteeManager()

    @State private var saisie = ""
    @State private var message = ""

    // Fenêtre de confirmation du paiement
    @State private var montantAConfirmer: Int?
    @State private var confirmationVocale = false

    // Fenêtre affichée après la clôture d'un service
    @State private var recapService: Service?

    @State private var indiceSelectionne = 0
    @State private var afficherActions = false
    @State private var afficherModification = false
    @State private var texteModification = ""
    @State private var afficherSuppression = false
    @State private var afficherAnciens = false

    @FocusState private var champActif: Bool

    var body: some View {
        ZStack {
            Couleurs.nuit.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("EASY CB")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Text("Total encaissé : \(formater(store.total))")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(Couleurs.accent)

                Text("Nombre de paiements : \(store.paiements.count)")
                    .font(.system(size: 20))
                    .foregroundColor(Color(white: 0.88))

                HStack(spacing: 10) {
                    TextField("", text: $saisie, prompt:
                        Text("Montant (ex : 12,50)").foregroundColor(Color(white: 0.65)))
                        .keyboardType(.decimalPad)
                        .focused($champActif)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 55)
                        .background(Couleurs.paiement)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        champActif = false
                        dictee.basculer()
                    } label: {
                        Image(systemName: dictee.enCours ? "mic.fill" : "mic")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(BoutonCB(
                        couleur: dictee.enCours ? Couleurs.rouge : Couleurs.turquoise
                    ))
                    .frame(width: 70)
                }

                Button("Ajouter paiement") { demanderConfirmation(depuisVoix: false) }
                    .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, taille: 19, gras: true))

                Button("Clôturer le service") {
                    if let service = store.cloturer() {
                        message = "Service clôturé et archivé !"
                        recapService = service
                    } else {
                        message = "Aucun paiement à archiver."
                    }
                }
                .buttonStyle(BoutonCB(couleur: Couleurs.bouton))

                Button("Consulter les anciens services") { afficherAnciens = true }
                    .buttonStyle(BoutonCB(couleur: Couleurs.bouton))

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(Couleurs.accent)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 40)

                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(Array(store.paiements.enumerated().reversed()), id: \.offset) { i, centimes in
                            Button("Paiement \(i + 1) : \(formater(centimes))") {
                                indiceSelectionne = i
                                afficherActions = true
                            }
                            .buttonStyle(BoutonCB(
                                couleur: Couleurs.paiement, taille: 18, hauteur: 42
                            ))
                        }
                    }
                }

                Text("version \(versionApp)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
            }
            .padding(20)
            .sheet(isPresented: $afficherModification) {
                ModificationView(texte: $texteModification) {
                    if let c = parserMontant(texteModification) {
                        store.modifier(indiceSelectionne, centimes: c)
                        message = "Paiement modifié !"
                    } else {
                        message = "Montant invalide."
                    }
                }
            }

            if let centimes = montantAConfirmer {
                ConfirmationPaiementView(
                    centimes: centimes,
                    delai: delaiValidation,
                    valider: validerPaiement,
                    annuler: annulerPaiement
                )
            }

            if let service = recapService {
                RecapClotureView(service: service) { recapService = nil }
            }
        }
        .onAppear {
            dictee.onMessage = { texte in message = texte }
            dictee.onTexte = { texte in recevoirDictee(texte) }
        }
        .onChange(of: champActif) { actif in
            if actif && dictee.enCours {
                dictee.arreter()
                message = "Dictée arrêtée."
            }
        }
        .confirmationDialog("Gestion du paiement", isPresented: $afficherActions, titleVisibility: .visible) {
            Button("Modifier le montant") {
                let c = store.paiements[indiceSelectionne]
                texteModification = String(format: "%.2f", Double(c) / 100)
                    .replacingOccurrences(of: ".", with: ",")
                afficherModification = true
            }
            Button("Supprimer le paiement", role: .destructive) { afficherSuppression = true }
            Button("Annuler", role: .cancel) {}
        }
        .alert("Confirmer la suppression", isPresented: $afficherSuppression) {
            Button("Non", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                store.supprimerPaiement(indiceSelectionne)
                message = "Paiement supprimé !"
            }
        } message: {
            Text("Voulez-vous vraiment supprimer ce paiement ?")
        }
        .sheet(isPresented: $afficherAnciens) {
            AnciensServicesView(store: store)
        }
    }

    // MARK: - Ajout d'un paiement (avec fenêtre de confirmation)

    private func demanderConfirmation(depuisVoix: Bool) {
        guard montantAConfirmer == nil else { return }
        guard let centimes = parserMontant(saisie) else {
            message = "Montant invalide."
            if depuisVoix { dictee.reprendre() }
            return
        }
        champActif = false
        confirmationVocale = depuisVoix
        montantAConfirmer = centimes
    }

    private func validerPaiement() {
        guard let centimes = montantAConfirmer else { return }
        montantAConfirmer = nil
        store.ajouter(centimes)
        saisie = ""
        message = "Paiement ajouté !"
        if confirmationVocale { dictee.reprendre() }
        confirmationVocale = false
    }

    private func annulerPaiement() {
        guard montantAConfirmer != nil else { return }
        montantAConfirmer = nil
        message = "Paiement annulé."
        if confirmationVocale {
            saisie = ""          // montant mal compris : on efface
            dictee.reprendre()
        }                         // en saisie manuelle, on garde le montant pour le corriger
        confirmationVocale = false
    }

    // MARK: - Dictée

    private func recevoirDictee(_ brut: String) {
        // Une fenêtre de confirmation est déjà ouverte : on ignore et on continue d'écouter.
        guard montantAConfirmer == nil else {
            dictee.reprendre()
            return
        }

        let montant = normaliserDictee(brut)
        guard !montant.isEmpty, parserMontant(montant) != nil else {
            message = "Aucun montant reconnu."
            dictee.reprendre()
            return
        }

        saisie = montant
        message = ""
        demanderConfirmation(depuisVoix: true)
    }
}

/// Fenêtre affichée après la clôture : propose d'envoyer le récapitulatif du service.
struct RecapClotureView: View {
    let service: Service
    var fermer: () -> Void

    @State private var partage: TexteAPartager?
    @State private var envoye = false

    var body: some View {
        let nombre = service.paiements.count

        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Service clôturé")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(formater(service.paiements.reduce(0, +)))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(Couleurs.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("\(nombre) paiement\(nombre > 1 ? "s" : "")")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.8))

                Button(envoye ? "Renvoyer le récapitulatif" : "Envoyer le récapitulatif") {
                    partage = TexteAPartager(texte: texteRecap(service))
                }
                .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, taille: 18, gras: true))

                Button(envoye ? "Fermer" : "Plus tard") { fermer() }
                    .buttonStyle(BoutonCB(couleur: Couleurs.bouton, taille: 17))
            }
            .padding(22)
            .background(Couleurs.nuit)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Couleurs.turquoise, lineWidth: 1)
            )
            .padding(24)
        }
        .sheet(item: $partage) { p in
            ShareSheet(items: [p.texte]) { ok in
                if ok { envoye = true }
            }
        }
    }
}

/// Fenêtre affichée avant d'ajouter un paiement : montant bien visible,
/// boutons Annuler / Valider, et ajout automatique à la fin du compte à rebours.
struct ConfirmationPaiementView: View {
    let centimes: Int
    let delai: Int
    var valider: () -> Void
    var annuler: () -> Void

    @State private var restant: Int

    init(centimes: Int, delai: Int, valider: @escaping () -> Void, annuler: @escaping () -> Void) {
        self.centimes = centimes
        self.delai = delai
        self.valider = valider
        self.annuler = annuler
        _restant = State(initialValue: delai)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Nouveau paiement")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(white: 0.85))

                Text(formater(centimes))
                    .font(.system(size: 54, weight: .bold))
                    .foregroundColor(Couleurs.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("Ajout automatique dans \(restant) s")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.75))

                HStack(spacing: 12) {
                    Button("Annuler") { annuler() }
                        .buttonStyle(BoutonCB(couleur: Couleurs.rouge, taille: 19, gras: true))
                    Button("Valider") { valider() }
                        .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, taille: 19, gras: true))
                }
            }
            .padding(22)
            .background(Couleurs.nuit)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Couleurs.turquoise, lineWidth: 1)
            )
            .padding(24)
        }
        .task {
            while restant > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                restant -= 1
            }
            if !Task.isCancelled { valider() }
        }
    }
}

struct AnciensServicesView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var indiceASupprimer: Int?
    @State private var texteAPartager: TexteAPartager?

    var body: some View {
        ZStack {
            Couleurs.nuit.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Anciens services")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                ScrollView {
                    VStack(spacing: 10) {
                        if store.donnees.anciens_services.isEmpty {
                            Text("Aucun ancien service.")
                                .foregroundColor(.white)
                                .padding(.top, 20)
                        }

                        ForEach(1...max(store.donnees.anciens_services.count, 1), id: \.self) { numero in
                            if numero <= store.donnees.anciens_services.count {
                                ligne(numero: numero)
                            }
                        }
                    }
                }

                Button("Fermer") { dismiss() }
                    .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, hauteur: 50))
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $texteAPartager) { t in
            ShareSheet(items: [t.texte])
        }
        .alert("Confirmer la suppression", isPresented: Binding(
            get: { indiceASupprimer != nil },
            set: { if !$0 { indiceASupprimer = nil } }
        )) {
            Button("Annuler", role: .cancel) { indiceASupprimer = nil }
            Button("Supprimer", role: .destructive) {
                if let i = indiceASupprimer { store.supprimerService(i) }
                indiceASupprimer = nil
            }
        } message: {
            Text("Voulez-vous vraiment supprimer cet ancien service ?")
        }
    }

    @ViewBuilder
    private func ligne(numero: Int) -> some View {
        let indice = store.donnees.anciens_services.count - numero
        let service = store.donnees.anciens_services[indice]
        let total = service.paiements.reduce(0, +)

        let details = service.paiements.enumerated().reversed()
            .map { "Paiement \($0.offset + 1) : \(formater($0.element))" }
            .joined(separator: "\n")

        HStack(alignment: .center, spacing: 8) {
            Text("Service \(numero) - \(service.date_cloture)\nTotal : \(formater(total))\nNombre de paiements : \(service.paiements.count)\n\(details)")
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Button("Envoyer") { texteAPartager = TexteAPartager(texte: texteRecap(service)) }
                    .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, taille: 13, hauteur: 38))
                Button("Supprimer") { indiceASupprimer = indice }
                    .buttonStyle(BoutonCB(couleur: Couleurs.rouge, taille: 13, hauteur: 38))
            }
            .frame(width: 90)
        }
        .padding(10)
        .background(Couleurs.paiement)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ModificationView: View {
    @Binding var texte: String
    var enregistrer: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            Couleurs.nuit.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Modifier le paiement")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                TextField("", text: $texte, prompt:
                    Text("Nouveau montant (€)").foregroundColor(Color(white: 0.65)))
                    .keyboardType(.decimalPad)
                    .focused($focus)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 55)
                    .background(Couleurs.paiement)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    Button("Annuler") { dismiss() }
                        .buttonStyle(BoutonCB(couleur: Couleurs.bouton, taille: 15, hauteur: 50))
                    Button("Enregistrer") {
                        enregistrer()
                        dismiss()
                    }
                    .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, taille: 15, hauteur: 50))
                }

                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .onAppear { focus = true }
    }
}
