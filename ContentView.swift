import SwiftUI

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
    @State private var montantEnAttente: String?
    @State private var tacheAjoutVocal: Task<Void, Never>?

    // Annulation du dernier paiement
    @State private var annulationVisible = false
    @State private var montantAjoute = 0
    @State private var nombreApresAjout = 0
    @State private var tacheAnnulation: Task<Void, Never>?

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
                        annulerAjoutVocal()
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

                Button("Ajouter paiement") { ajouterPaiement() }
                    .buttonStyle(BoutonCB(couleur: Couleurs.turquoise, taille: 19, gras: true))

                Button("Clôturer le service") {
                    masquerAnnulation()
                    message = store.cloturer()
                        ? "Service clôturé et archivé !"
                        : "Aucun paiement à archiver."
                }
                .buttonStyle(BoutonCB(couleur: Couleurs.bouton))

                Button("Consulter les anciens services") { afficherAnciens = true }
                    .buttonStyle(BoutonCB(couleur: Couleurs.bouton))

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(Couleurs.accent)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 40)

                if annulationVisible {
                    HStack(spacing: 10) {
                        Text("Paiement ajouté : \(formater(montantAjoute))")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Annuler") { annulerDernierPaiement() }
                            .buttonStyle(BoutonCB(couleur: Couleurs.rouge, taille: 15, hauteur: 38))
                            .frame(width: 100)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Couleurs.paiement)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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
            }
            .padding(20)
            .sheet(isPresented: $afficherModification) {
                ModificationView(texte: $texteModification) {
                    if let c = parserMontant(texteModification) {
                        masquerAnnulation()
                        store.modifier(indiceSelectionne, centimes: c)
                        message = "Paiement modifié !"
                    } else {
                        message = "Montant invalide."
                    }
                }
            }
        }
        .onAppear {
            dictee.onMessage = { texte in message = texte }
            dictee.onTexte = { texte in recevoirDictee(texte) }
        }
        .onChange(of: saisie) { nouvelle in
            if let attendu = montantEnAttente, nouvelle != attendu {
                annulerAjoutVocal()
                message = "Ajout automatique annulé."
            }
        }
        .onChange(of: champActif) { actif in
            if actif && (dictee.enCours || montantEnAttente != nil) {
                dictee.arreter()
                annulerAjoutVocal()
                message = "Dictée arrêtée. Montant non ajouté."
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
                masquerAnnulation()
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

    // MARK: - Actions

    private func ajouterPaiement() {
        guard let centimes = parserMontant(saisie) else {
            message = "Montant invalide."
            return
        }
        montantEnAttente = nil
        store.ajouter(centimes)
        saisie = ""
        champActif = false
        message = ""
        afficherAnnulation(centimes)
    }

    // MARK: - Annulation du dernier paiement

    private func afficherAnnulation(_ centimes: Int) {
        tacheAnnulation?.cancel()
        montantAjoute = centimes
        nombreApresAjout = store.paiements.count
        annulationVisible = true

        tacheAnnulation = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if Task.isCancelled { return }
            annulationVisible = false
        }
    }

    private func masquerAnnulation() {
        tacheAnnulation?.cancel()
        tacheAnnulation = nil
        annulationVisible = false
    }

    private func annulerDernierPaiement() {
        defer { masquerAnnulation() }
        guard store.paiements.count == nombreApresAjout,
              store.paiements.last == montantAjoute else {
            message = "Annulation impossible."
            return
        }
        store.supprimerPaiement(nombreApresAjout - 1)
        message = "Dernier paiement annulé."
    }

    // MARK: - Dictée

    private func recevoirDictee(_ brut: String) {
        let montant = normaliserDictee(brut)
        guard !montant.isEmpty, parserMontant(montant) != nil else {
            message = "Aucun montant reconnu."
            dictee.reprendre()
            return
        }

        tacheAjoutVocal?.cancel()
        montantEnAttente = montant
        saisie = montant
        message = "Montant : \(montant)\nAjout dans 3 secondes. Modifiez le champ pour annuler."

        tacheAjoutVocal = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { return }
            guard montantEnAttente == montant, saisie == montant else { return }
            ajouterPaiement()
            dictee.reprendre()
        }
    }

    private func annulerAjoutVocal() {
        tacheAjoutVocal?.cancel()
        tacheAjoutVocal = nil
        montantEnAttente = nil
    }
}

struct AnciensServicesView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var indiceASupprimer: Int?

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

            Button("Supprimer") { indiceASupprimer = indice }
                .buttonStyle(BoutonCB(couleur: Couleurs.rouge, taille: 13, hauteur: 38))
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
