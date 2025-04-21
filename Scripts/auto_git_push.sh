#!/bin/bash

# global_auto_git_push.sh
# Ein universelles Git-Push-Skript für alle hero-Projekte
# Version: 1.0.0 (2025-04-21)

# Farbdefinitionen
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion zum Ausführen des Git-Pushs für ein Projekt
auto_git_push_for_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    
    # Überprüfen, ob es sich um ein hero-Projekt handelt
    if [[ ! "$project_name" =~ ^hero[0-9]+ ]]; then
        return 0
    fi
    
    # Überprüfen, ob es ein Git-Repository ist
    if [ ! -d "${project_path}/.git" ]; then
        return 0
    fi
    
    # Wichtige Pfade
    local log_file="${project_path}/Scripts/cron.log"
    local lock_file="${project_path}/.git/auto_push.lock"
    
    # Prüfen auf Lock-Datei (verhindert parallele Ausführungen)
    if [ -f "$lock_file" ]; then
        # Prüfe, ob der Lock älter als 10 Minuten ist
        local lock_time=$(date -r "$lock_file" +%s)
        local current_time=$(date +%s)
        local diff=$((current_time - lock_time))
        
        if [ $diff -gt 600 ]; then
            echo "[$(date)] GIT: Alter Lock gefunden. Entferne veralteten Lock." >> "$log_file"
            rm "$lock_file"
        else
            echo "[$(date)] GIT: Ein anderer Git-Push läuft bereits. Überspringe." >> "$log_file"
            return 0
        fi
    fi
    
    # Lock erstellen
    touch "$lock_file"
    
    # Timestamp für Logs und Commit-Nachrichten
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Protokoll beginnen
    echo "[$(date)] GIT: Starte Git-Push für $project_name..." >> "$log_file"
    
    # Ins Projektverzeichnis wechseln
    cd "$project_path" || {
        echo "[$(date)] GIT: Fehler - Konnte nicht ins Projektverzeichnis wechseln." >> "$log_file"
        rm -f "$lock_file"
        return 1
    }
    
    # Prüfen auf ungesicherte Änderungen
    if [ -z "$(git status --porcelain)" ]; then
        echo "[$(date)] GIT: Keine Änderungen vorhanden, die gesichert werden müssen." >> "$log_file"
        rm -f "$lock_file"
        return 0
    fi
    
    # Automatischer Commit
    echo "[$(date)] GIT: Ungesicherte Änderungen gefunden. Führe automatischen Commit durch..." >> "$log_file"
    
    # Git-Status anzeigen und loggen
    git status --short >> "$log_file"
    
    # Alles stagen und committen
    git add .
    git commit -m "Automatischer Commit durch global_auto_git_push.sh - $timestamp"
    
    # Push versuchen
    echo "[$(date)] GIT: Versuche Push zum Remote-Repository..." >> "$log_file"
    if git push 2>> "$log_file"; then
        echo "[$(date)] GIT: Git-Push erfolgreich durchgeführt." >> "$log_file"
    else
        echo "[$(date)] GIT: Git-Push fehlgeschlagen. Siehe Log für Details." >> "$log_file"
        echo "[$(date)] GIT: Hinweis - Manueller Push später erforderlich." >> "$log_file"
    fi
    
    # Lock entfernen
    rm -f "$lock_file"
}

# Hauptfunktion
main() {
    # Parameter für den Projektpfad
    local project_path="$1"
    
    # Wenn kein Pfad angegeben ist, alle hero-Projekte durchsuchen
    if [ -z "$project_path" ]; then
        # Suche alle hero-Projekte
        for dir in /Users/ninaklee/Projects/hero*; do
            if [ -d "$dir" ]; then
                auto_git_push_for_project "$dir"
            fi
        done
    else
        # Nur das angegebene Projekt
        auto_git_push_for_project "$project_path"
    fi
}

# Skript ausführbar machen
chmod +x "$0"

# Hauptfunktion aufrufen
main "$1"
