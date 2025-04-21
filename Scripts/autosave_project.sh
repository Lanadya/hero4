#!/bin/bash

# global_autosave_project.sh
# Ein universelles Projektsicherungs-Skript für alle hero-Projekte
# Version: 1.0.0 (2025-04-21)

# Farbdefinitionen
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion zum Ausführen der Projektsicherung für ein Projekt
create_backup_for_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    
    # Überprüfen, ob es sich um ein hero-Projekt handelt
    if [[ ! "$project_name" =~ ^hero[0-9]+ ]]; then
        return 0
    fi
    
    # Wichtige Pfade
    local backup_dir="${project_path}/Backups"
    local log_file="${project_path}/Scripts/cron.log"
    local exclude_file="${project_path}/Scripts/.backup_exclude"
    
    # Wenn das Backup-Verzeichnis nicht existiert, erstellen
    mkdir -p "$backup_dir"
    
    # Protokoll beginnen
    echo "[$(date)] BACKUP: Erstelle Projektsicherung für $project_name..." >> "$log_file"
    
    # Timestamp für die Dateinamen
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local backup_file="${backup_dir}/${project_name}_backup_${timestamp}.tar.gz"
    
    # Prüfen, ob ein Backup-Ausschluss existiert, sonst erstellen
    if [ ! -f "$exclude_file" ]; then
        echo "[$(date)] BACKUP: Erstelle Backup-Ausschluss-Datei..." >> "$log_file"
        cat > "$exclude_file" << EOF
# Dateien und Verzeichnisse, die von der Projektsicherung ausgeschlossen werden sollen
.git/*
Backups/*
*.xcodeproj/xcuserdata/*
*.xcodeproj/project.xcworkspace/xcuserdata/*
.DS_Store
*.o
*.lo
*.la
*.al
.libs
*.so
*.so.[0-9]*
*.a
*.pyc
*.pyo
__pycache__
build/
DerivedData/
EOF
    fi
    
    # Prüfen auf laufende Xcode-Prozesse oder Bearbeitungssitzungen
    if pgrep -f Xcode > /dev/null; then
        echo "[$(date)] BACKUP: Xcode läuft - Sichere nur Projekt-Dateien..." >> "$log_file"
    fi
    
    # Projektsicherung erstellen
    tar -czf "$backup_file" \
        --exclude-from="$exclude_file" \
        -C "$(dirname "$project_path")" "$(basename "$project_path")" \
        2>> "$log_file"
    
    # Prüfe, ob das Backup erfolgreich erstellt wurde
    if [ -f "$backup_file" ]; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo "[$(date)] BACKUP: Projektsicherung erfolgreich erstellt: $backup_file ($backup_size)" >> "$log_file"
    else
        echo "[$(date)] BACKUP: Fehler beim Erstellen der Projektsicherung" >> "$log_file"
        return 1
    fi
    
    # Auto-Cleaning: Behalte nur die letzten 5 Sicherungen
    local backup_count=$(ls -1 "${backup_dir}/${project_name}_backup_"* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$backup_count" -gt 5 ]; then
        local excess=$((backup_count - 5))
        if [ "$excess" -gt 0 ]; then
            echo "[$(date)] BACKUP: Lösche $excess alte Sicherung(en)..." >> "$log_file"
            ls -1t "${backup_dir}/${project_name}_backup_"* | tail -n "$excess" | xargs rm 2>/dev/null
        fi
    fi
    
    # Zeige Zusammenfassung an
    local backup_dir_size=$(du -sh "$backup_dir" | cut -f1)
    echo "[$(date)] BACKUP: Backup-Verzeichnisgröße: $backup_dir_size, Aktuelle Sicherung: $backup_size" >> "$log_file"
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
                create_backup_for_project "$dir"
            fi
        done
    else
        # Nur das angegebene Projekt
        create_backup_for_project "$project_path"
    fi
}

# Skript ausführbar machen
chmod +x "$0"

# Hauptfunktion aufrufen
main "$1"
