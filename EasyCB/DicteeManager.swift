import Foundation
import Speech
import AVFoundation

/// Dictée vocale continue : écoute, renvoie le texte reconnu, puis attend `reprendre()`.
final class DicteeManager: ObservableObject {
    @Published var enCours = false      // dictée continue activée (bouton micro rouge)
    @Published var ecoute = false       // micro réellement ouvert

    var onTexte: ((String) -> Void)?
    var onMessage: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silence: Timer?
    private var generation = 0
    private var dernierTexte = ""

    func basculer() {
        if enCours {
            arreter()
            onMessage?("Dictée arrêtée.")
        } else {
            demanderAutorisations()
        }
    }

    func arreter() {
        enCours = false
        generation += 1
        nettoyer()
    }

    /// À appeler une fois le montant traité pour relancer l'écoute.
    func reprendre() {
        guard enCours else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.demarrer()
        }
    }

    private func demanderAutorisations() {
        SFSpeechRecognizer.requestAuthorization { statut in
            DispatchQueue.main.async {
                guard statut == .authorized else {
                    self.onMessage?("Reconnaissance vocale refusée (Réglages > EASY CB).")
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { accorde in
                    DispatchQueue.main.async {
                        guard accorde else {
                            self.onMessage?("Autorisation du microphone refusée.")
                            return
                        }
                        self.enCours = true
                        self.demarrer()
                    }
                }
            }
        }
    }

    private func demarrer() {
        guard enCours else { return }
        guard let recognizer, recognizer.isAvailable else {
            enCours = false
            onMessage?("Reconnaissance vocale indisponible.")
            return
        }

        nettoyer()
        generation += 1
        let g = generation
        dernierTexte = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let noeud = engine.inputNode
            let format = noeud.outputFormat(forBus: 0)
            noeud.removeTap(onBus: 0)
            noeud.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            engine.prepare()
            try engine.start()
            ecoute = true
            onMessage?("Écoute en cours... Parlez.")

            task = recognizer.recognitionTask(with: req) { [weak self] resultat, erreur in
                DispatchQueue.main.async {
                    guard let self, g == self.generation else { return }

                    if let resultat {
                        self.dernierTexte = resultat.bestTranscription.formattedString
                        self.relancerSilence(g)
                        if resultat.isFinal {
                            self.terminer(g)
                            return
                        }
                    }
                    if erreur != nil && resultat == nil {
                        self.terminer(g)
                    }
                }
            }
        } catch {
            enCours = false
            ecoute = false
            onMessage?("Erreur microphone : \(error.localizedDescription)")
        }
    }

    /// Après 1,5 s sans nouveau mot, on clôt l'écoute pour obtenir le résultat final.
    private func relancerSilence(_ g: Int) {
        silence?.invalidate()
        silence = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self, g == self.generation else { return }
            self.request?.endAudio()
        }
    }

    private func terminer(_ g: Int) {
        guard g == generation else { return }
        let texte = dernierTexte.trimmingCharacters(in: .whitespaces)
        generation += 1
        nettoyer()

        if texte.isEmpty {
            reprendre()        // rien entendu : on réécoute
        } else {
            onTexte?(texte)    // la vue relancera l'écoute avec reprendre()
        }
    }

    private func nettoyer() {
        silence?.invalidate()
        silence = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        ecoute = false
    }
}
