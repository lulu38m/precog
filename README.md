# ✋ Precog

**Pilote ton Mac à mains nues, comme dans *Minority Report*.**

<p align="center">
  <img src="docs/demo.gif" alt="Démo de Precog : une main en néon balaie l'air et le Mac change de bureau" width="720">
</p>

Precog est une petite app de barre de menus pour macOS. Elle regarde ta main avec la webcam et transforme des gestes simples en actions système : pas de casque, pas de gants, juste la caméra de ton Mac.

| Geste | Action |
|---|---|
| ✋ Doigts tendus ¼ s (le poignet peut être hors champ) | Arme la détection |
| 👋 Balayer ← → | Bureau précédent / suivant |
| ☝️ Balayer ↑ | Mission Control |
| 👇 Balayer ↓ | Fenêtres de l'app (désactivé par défaut) |

🔒 **100 % local** : la main est analysée sur ton Mac avec le framework Vision d'Apple. Aucune image n'est enregistrée ni envoyée.

## Installation

> Nécessite **macOS 14 Sonoma** ou plus récent et une webcam (caméra intégrée, webcam USB ou iPhone en Continuity Camera).

1. Télécharge **`Precog.zip`** dans la [dernière version](../../releases/latest).
2. Décompresse-le et glisse **Precog.app** dans le dossier **Applications**.
3. Ouvre Precog : l'app est signée et notarisée par Apple, elle se lance directement.
4. Une icône ✋ apparaît dans la barre de menus et l'écran d'accueil te guide pour autoriser :
   - la **Caméra**, pour voir ta main ;
   - l'**Accessibilité**, pour que tes gestes puissent changer de bureau.
5. Crée au moins 2 bureaux (Mission Control › ＋), montre tes doigts tendus, puis balaie.

## Fonctionnalités

- Icône dans la barre de menus avec aperçu caméra et **squelette de la main en néon** (21 points)
- **Mode hologramme** : ta main en néon sur fond noir, avec traînée lumineuse, sans jamais afficher l'image de la caméra
- **Fenêtre hologramme flottante**, visible sur tous les bureaux : parfaite pour enregistrer une démo
- **Bulle de confirmation** façon « volume macOS » à chaque geste
- **Réglages** : caméra (dont la Vue du bureau), sensibilité, sens du balayage, choix des gestes, lancement à l'ouverture de session
- **Arrêt d'urgence** : raccourci global (⌃⌥⌘G par défaut) pour tout mettre en pause
- **Écran d'accueil** qui guide pour les autorisations
- Effet **Liquid Glass** sur macOS 26, matériau flou sur macOS 14–15

## Dépannage

**Le geste est détecté mais le bureau ne change pas**
- Vérifie que Precog est coché dans Réglages Système › Confidentialité et sécurité › Accessibilité.
- S'il est déjà coché, retire-le (−), relance Precog, puis rajoute-le. Ou en terminal :
  ```bash
  tccutil reset Accessibility com.precog.app
  ```
- Vérifie que les raccourcis « Aller d'un espace à gauche / à droite » (⌃← / ⌃→) sont activés dans Réglages Système › Clavier › Raccourcis clavier › Mission Control.

**Je dois lever la main trop haut** : dans les réglages de Precog, choisis la caméra **Vue du bureau** si elle est proposée, ou incline un peu l'écran vers toi.

**Trop de déclenchements involontaires** : baisse la sensibilité vers « Ample » dans les réglages.

**La caméra ne s'allume pas** : Réglages Système › Confidentialité et sécurité › Caméra › active Precog.

## Compiler depuis les sources

Prérequis : Xcode 16 ou plus récent (Xcode 26 recommandé pour l'effet Liquid Glass) et [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone <url-de-ce-dépôt>
cd Precog
make            # génère Precog.xcodeproj et l'ouvre dans Xcode
```

Dans Xcode, cible **Precog** › **Signing & Capabilities** › **Team** : choisis ton Apple ID (« Personal Team »), puis ▶️ (⌘R).
Une signature stable évite que macOS oublie l'autorisation d'Accessibilité à chaque compilation.

| Commande | Effet |
|---|---|
| `make` | Génère le projet Xcode et l'ouvre |
| `make install` | Compile en Release, installe dans /Applications et lance l'app |
| `make release` | Crée `build/Precog.zip` signé « Developer ID » et notarisé par Apple (compte Apple Developer requis) |
| `make clean` | Supprime le projet généré et les fichiers de compilation |

### Architecture

```
Precog/
├── App/
│   ├── PrecogApp.swift           # Point d'entrée, icône de barre de menus
│   └── PrecogController.swift    # État global : relie caméra, moteur, actions, UI
├── Engine/
│   ├── CameraManager.swift       # Webcam (AVFoundation) + détection de la main (Vision)
│   ├── GestureEngine.swift       # Armement (doigts tendus) + détection des balayages
│   ├── Gestures.swift            # Gestes, actions et réglages de détection
│   ├── ActionPerformer.swift     # Simule ⌃← ⌃→ ⌃↑ ⌃↓ (CGEvent)
│   ├── Permissions.swift         # Caméra et Accessibilité
│   └── Preferences.swift         # Préférences + raccourci d'arrêt d'urgence
└── UI/
    ├── MenuPanelView.swift       # Panneau de la barre de menus
    ├── CameraPreview.swift       # Aperçu caméra en miroir
    ├── HandSkeletonOverlay.swift # Squelette néon
    ├── HologramView.swift        # Mode hologramme (grille, traînée, scanlines)
    ├── HUDController.swift       # Bulle de confirmation flottante
    ├── OnboardingView.swift      # Écran d'accueil
    ├── SettingsView.swift        # Réglages
    ├── WindowPresenter.swift     # Ouverture des fenêtres
    └── Theme.swift               # Couleurs, effet verre
```

## Pourquoi pas sur le Mac App Store ?

Pour changer de bureau, Precog simule des raccourcis clavier grâce à l'Accessibilité, ce que le bac à sable du Mac App Store interdit. Comme BetterTouchTool ou Rectangle, Precog se distribue donc directement depuis GitHub.

## Feuille de route

- [ ] Pincer pour cliquer
- [ ] Attraper / déplacer une fenêtre (main qui se ferme)
- [ ] Gestes personnalisables (n'importe quel raccourci clavier)
- [ ] Mode deux mains : zoom
- [x] Version signée et notarisée par Apple
- [ ] Icône d'app

## Licence

MIT, voir [LICENSE](LICENSE).
