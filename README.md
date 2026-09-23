# Caffè 2.0

App solo menu-bar che tiene sveglio il Mac tramite `caffeinate`, con durate a tempo,
notifiche native e avvio al login. Rimpiazza l'applet AppleScript omonima.

> Repository privata. L'app compilata è in **Releases** (allegato `Caffè-*.zip`).
> L'app è firmata **ad-hoc** (non notarizzata): dopo aver scompattato e copiato
> `Caffè.app` in `~/Applications`, macOS la blocca al primo avvio. Per sbloccarla
> (una volta sola, poi parte normale):
>
>     xattr -dr com.apple.quarantine ~/Applications/Caffè.app
>
> (equivalente: Impostazioni di sistema → Privacy e sicurezza → **Apri comunque**).
> Alternativa senza alcuno sblocco: clonare la repo e compilare con `./build.sh`.

## Uso

- **Clic sinistro** sull'icona ☕ = menu completo: slider di durata (Spento, 10 min, 30 min, 1 ora, 2 ore, 4 ore, 8 ore, Infinito), flag ASSERTIONS, impostazioni, versione.
- **Clic destro (o ⌥-clic)** = attiva/disattiva subito con l'ultima durata usata.
- "Disattiva ora" spegne subito; allo scadere del timer arriva una notifica.
- Notifiche anti-flood: i cambi fatti col menu producono al massimo UN popup, alla chiusura del menu e solo se il timer è davvero cambiato; fuori dal menu (clic destro) arriva 2s dopo l'ultima azione.
- "Attiva quando alimentato" / "Spegni su batteria": automazione in base all'alimentazione.
- "Avvia al login" registra l'app in Impostazioni → Generali → Elementi login.
- Uscendo dall'app il Mac torna dormibile.

## Build e installazione

    ./build.sh          # interattivo: chiede conferma per sostituire il vecchio Caffè
    ./build.sh --yes    # non interattivo

Richiede solo i Command Line Tools (`xcode-select --install`).

## Risoluzione problemi

**`permission denied: ./build.sh`** — lo ZIP scaricato da GitHub perde il bit
di eseguibilità (il `git clone` lo preserva). Soluzione:

    bash build.sh
    chmod +x build.sh && ./build.sh   # oppure, una volta per tutte

**`swift: command not found` / `unable to get active developer directory`** —
mancano i Command Line Tools e installarli richiede admin. Nessun passo di
`build.sh` richiede admin: il muro è solo l'installazione dei tool. Su un Mac
senza admin (es. aziendale): verifica se esistono già con `swift --version`;
se mancano, non puoi compilare su quel Mac — usa l'app compilata dalla
Release, che non richiede admin (sblocco con `xattr`, vedi sopra) e funziona
da qualsiasi cartella della tua Home:

    cd ~/Downloads && unzip -o Caffe-*.zip
    xattr -dr com.apple.quarantine Caffè.app
    open Caffè.app

Diagnosi rapida: `xcode-select -p; swift --version; ls -l build.sh`.

## Personalizzare le durate

Modifica `defaultDurations` in `Sources/CaffeCore/Core.swift`, poi riesegui `./build.sh`.
