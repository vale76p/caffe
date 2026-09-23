# Caffè 2.0

App solo menu-bar che tiene sveglio il Mac tramite `caffeinate`, con durate a tempo,
notifiche native e avvio al login. Rimpiazza l'applet AppleScript omonima.

## Uso

- **Clic sinistro** sull'icona ☕ = attiva/disattiva subito con l'ultima durata usata.
- **Clic destro (o ⌥-clic)** = menu completo: slider di durata (Spento, 10 min, 30 min, 1 ora, 2 ore, 4 ore, 8 ore, Infinito), flag ASSERTIONS, impostazioni, versione.
- "Disattiva ora" spegne subito; allo scadere del timer arriva una notifica.
- "Attiva quando alimentato" / "Spegni su batteria": automazione in base all'alimentazione.
- "Avvia al login" registra l'app in Impostazioni → Generali → Elementi login.
- Uscendo dall'app il Mac torna dormibile.

## Build e installazione

    ./build.sh          # interattivo: chiede conferma per sostituire il vecchio Caffè
    ./build.sh --yes    # non interattivo

Richiede solo i Command Line Tools (`xcode-select --install`).

## Personalizzare le durate

Modifica `defaultDurations` in `Sources/CaffeCore/Core.swift`, poi riesegui `./build.sh`.
