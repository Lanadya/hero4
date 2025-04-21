#!/bin/bash

# global_auto_status_snapshot.sh
# Ein universelles Status-Snapshot-Skript für alle hero-Projekte
# Version: 1.0.0 (2025-04-21)

# Farbdefinitionen
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion zum Ausführen des Snapshots für ein Projekt
create_snapshot_for_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    
    # Überprüfen, ob es sich um ein hero-Projekt handelt
    if [[ ! "$project_name" =~ ^hero[0-9]+ ]]; then
        return 0
    fi
    
    # Wichtige Pfade
    local doc_dir="${project_path}/Dokumentation"
    local status_file="${doc_dir}/CURRENT_WORK.md"
    local snapshot_dir="${doc_dir}/Status/Snapshots"
    local log_file="${project_path}/Scripts/cron.log"
    
    # Wenn die CURRENT_WORK.md nicht existiert, ist dieses Projekt nicht mit unserer Methode konfiguriert
    if [ ! -f "$status_file" ]; then
        return 0
    fi
    
    # Timestamp für die Dateinamen
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    
    # Protokoll beginnen
    echo "[$(date)] SNAPSHOT: Erstelle Status-Snapshot für $project_name..." >> "$log_file"
    
    # Verzeichnisse erstellen, falls sie nicht existieren
    mkdir -p "$snapshot_dir"
    
    # Snapshot erstellen
    local snapshot_file="${snapshot_dir}/snapshot_${timestamp}.md"
    cp "$status_file" "$snapshot_file"
    
    # Auto-Cleaning: Behalte nur die letzten 100 Snapshots
    local snapshot_count=$(ls -1 "${snapshot_dir}/snapshot_"* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$snapshot_count" -gt 100 ]; then
        local excess=$((snapshot_count - 100))
        if [ "$excess" -gt 0 ]; then
            echo "[$(date)] SNAPSHOT: Lösche $excess alte Snapshots..." >> "$log_file"
            ls -1t "${snapshot_dir}/snapshot_"* | tail -n "$excess" | xargs rm 2>/dev/null
        fi
    fi
    
    echo "[$(date)] SNAPSHOT: Status-Snapshot erfolgreich erstellt für $project_name: $snapshot_file" >> "$log_file"
    
    # Größeninformationen
    local project_size=$(du -sh "$project_path" | cut -f1)
    local snapshot_dir_size=$(du -sh "$snapshot_dir" | cut -f1)
    echo "[$(date)] SNAPSHOT: Projekt-Größe: $project_size, Snapshot-Verzeichnis: $snapshot_dir_size" >> "$log_file"
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
                create_snapshot_for_project "$dir"
            fi
        done
    else
        # Nur das angegebene Projekt
        create_snapshot_for_project "$project_path"
    fi
}

# Skript ausführbar machen
chmod +x "$0"

# Hauptfunktion aufrufen
main "$1"
