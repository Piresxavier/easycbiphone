# EASY CB pour iPhone (SwiftUI)

App iPhone native : mêmes fonctions que la version Android (paiements, total, modification/suppression,
clôture de service, anciens services, dictée vocale avec ajout automatique après 3 s).
Les données sont enregistrées dans `journal_cb.json` (même format que sur Android).

## Option A : tu as un Mac
1. Installe XcodeGen : `brew install xcodegen`
2. Dans ce dossier : `xcodegen generate`
3. Ouvre `EasyCB.xcodeproj` dans Xcode, choisis ton iPhone, règle « Signing » avec ton Apple ID, puis Run.

## Option B : pas de Mac (compilation dans le cloud, gratuit)
1. Crée un compte sur github.com et un dépôt **privé** vide, nommé par exemple `easycb`.
2. Envoie tout le contenu de ce dossier à la racine du dépôt (bouton « Add file > Upload files »).
   Si le dossier caché `.github` n'a pas été envoyé : « Add file > Create new file », tape
   `.github/workflows/build.yml` comme nom et colle le contenu du fichier `build.yml`.
3. Onglet **Actions** : le build « Build EASY CB (iOS) » se lance tout seul (3 à 6 minutes).
   Sinon : « Run workflow ».
4. Quand il est vert, ouvre-le et télécharge l'artefact **EasyCB-ipa** (un zip contenant `EasyCB.ipa`).
5. Installe l'IPA sur ton iPhone avec **Sideloadly** (Windows ou Mac, sideloadly.io) :
   branche l'iPhone, glisse `EasyCB.ipa`, saisis ton Apple ID, clique Start.
6. Sur l'iPhone : Réglages > Général > VPN et gestion de l'appareil > fais confiance à ton Apple ID.
   Active aussi le « Mode développeur » (Réglages > Confidentialité et sécurité) si iOS le demande.

Limite d'un Apple ID gratuit : l'app expire au bout de 7 jours, il faut la réinstaller avec Sideloadly
(les données restent si tu réinstalles par-dessus). Avec un compte Apple Developer payant (99 €/an),
tu peux utiliser TestFlight : l'app dure 90 jours et s'installe sans câble.

## Dictée vocale
Au premier appui sur le micro, iOS demande l'accès au micro puis à la reconnaissance vocale.
Parle (« 12 euros 50 » ou « 12,50 »), le montant s'affiche et s'ajoute après 3 secondes.
Touche le champ montant pour annuler.
