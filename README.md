# Caffè 2.0

App solo menu-bar che tiene sveglio il Mac tramite `caffeinate`, con durate a tempo,
notifiche native e avvio al login. Rimpiazza l'applet AppleScript omonima.

## Uso

- Clic sull'icona ☕ nella barra dei menu → scegli una durata (10 min … Infinito).
- "Disattiva ora" spegne subito; allo scadere del timer arriva una notifica.
- "Avvia al login" registra l'app in Impostazioni → Generali → Elementi login.
- Uscendo dall'app il Mac torna dormibile.

## Build e installazione

    ./build.sh          # interattivo: chiede conferma per sostituire il vecchio Caffè
    ./build.sh --yes    # non interattivo

Richiede solo i Command Line Tools (`xcode-select --install`).

## Personalizzare le durate

Modifica `defaultDurations` in `Sources/CaffeCore/Core.swift`, poi riesegui `./build.sh`.
