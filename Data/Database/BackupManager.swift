//
//  BackupManager.swift
//  hero4
//
//  Created by Nina Klee on 26.03.25.
//


import Foundation
import GRDB
// Fix für Process API
#if canImport(Darwin)
import Darwin
#endif

class BackupManager {
    static let shared = BackupManager()

    private init() {}

    // MARK: - Benutzer-Funktionen
    
    // Erstellt ein Backup der Datenbank
    func createBackup() -> URL? {
        do {
            // Hole den Pfad der Datenbank
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = folderURL.appendingPathComponent("gradeHero.sqlite")

            // Erstelle eine Backup-Datei mit Zeitstempel
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            let backupURL = folderURL.appendingPathComponent("gradeHero_backup_\(timestamp).sqlite")

            // Kopiere die Datenbankdatei
            try fileManager.copyItem(at: dbURL, to: backupURL)

            print("DEBUG BackupManager: Backup erstellt unter \(backupURL.path)")
            return backupURL
        } catch {
            print("ERROR BackupManager: Fehler beim Erstellen des Backups: \(error)")
            return nil
        }
    }

    // Stellt ein Backup wieder her
    func restoreBackup(from backupURL: URL) -> Bool {
        do {
            // Hole den Pfad der Datenbank
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let dbURL = folderURL.appendingPathComponent("gradeHero.sqlite")

            // Sichere die aktuelle Datenbank als temporäres Backup
            let tempBackupURL = folderURL.appendingPathComponent("temp_backup_before_restore.sqlite")
            if fileManager.fileExists(atPath: dbURL.path) {
                try fileManager.copyItem(at: dbURL, to: tempBackupURL)
            }

            // Ersetze die Datenbankdatei
            if fileManager.fileExists(atPath: dbURL.path) {
                try fileManager.removeItem(at: dbURL)
            }
            try fileManager.copyItem(at: backupURL, to: dbURL)

            // Lösche das temporäre Backup, wenn alles erfolgreich war
            if fileManager.fileExists(atPath: tempBackupURL.path) {
                try fileManager.removeItem(at: tempBackupURL)
            }

            print("DEBUG BackupManager: Backup wiederhergestellt von \(backupURL.path)")
            return true
        } catch {
            print("ERROR BackupManager: Fehler beim Wiederherstellen des Backups: \(error)")
            return false
        }
    }

    // Listet alle verfügbaren Backups auf
    func listAvailableBackups() -> [URL] {
        do {
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )

            let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            let backupURLs = fileURLs.filter { $0.lastPathComponent.hasPrefix("gradeHero_backup_") }

            return backupURLs.sorted { $0.lastPathComponent > $1.lastPathComponent } // Neueste zuerst
        } catch {
            print("ERROR BackupManager: Fehler beim Auflisten der Backups: \(error)")
            return []
        }
    }

    // Löscht ein Backup
    func deleteBackup(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("ERROR BackupManager: Fehler beim Löschen des Backups: \(error)")
            return false
        }
    }

    // MARK: - Entwickler-Hilfsfunktionen
    // Die folgenden Funktionen sind hauptsächlich für Entwicklungszwecke gedacht
    
    // Erstellt ein automatisches Backup (für Entwicklungszwecke)
    func createAutomaticBackup() -> URL? {
        print("DEBUG BackupManager: Erstelle automatisches Backup vor Simulator-Wechsel")
        return createBackup()
    }

    // Validiert ein Backup (für Entwicklungszwecke)
    func validateBackup(at url: URL) -> Bool {
        do {
            // Versuche, die Backup-Datei zu öffnen
            let dbQueue = try DatabaseQueue(path: url.path)
            
            // Überprüfe, ob alle wichtigen Tabellen existieren
            let requiredTables = ["classes", "students", "seatingPositions", "ratings"]
            let tableCheck = try dbQueue.read { db in
                for table in requiredTables {
                    let tableExists = try db.tableExists(table)
                    if !tableExists {
                        print("ERROR BackupManager: Tabelle '\(table)' fehlt im Backup")
                        return false
                    }
                }
                return true
            }
            
            return tableCheck
        } catch {
            print("ERROR BackupManager: Fehler bei der Backup-Validierung: \(error)")
            return false
        }
    }

    // Komprimiert ein Backup (für Entwicklungszwecke)
    func compressBackup(at url: URL) -> URL? {
        do {
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            // Erstelle einen komprimierten Backup-Pfad
            let compressedURL = folderURL.appendingPathComponent("\(url.lastPathComponent).zip")
            
            // Wir erstellen ein Data-Objekt aus der Datei
            let fileData = try Data(contentsOf: url)
            
            // Schreibe die Daten einfach mit einem Hinweis in eine neue Datei
            // (Echte Komprimierung würde ein ZIP-Framework benötigen)
            let compressedData = "BACKUP_DATA: \(url.lastPathComponent)\n".data(using: .utf8)! + fileData
            try compressedData.write(to: compressedURL)
            
            print("DEBUG BackupManager: Backup markiert als komprimiert")
            return compressedURL
        } catch {
            print("ERROR BackupManager: Fehler bei der Komprimierung: \(error)")
            return nil
        }
    }

    // Stellt ein komprimiertes Backup wieder her (für Entwicklungszwecke)
    func restoreCompressedBackup(from url: URL) -> Bool {
        do {
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            // Lese die "komprimierte" Datei
            let compressedData = try Data(contentsOf: url)
            
            // Finde die originale Datei
            // (In einer echten Implementierung würden wir hier entpacken)
            guard let dataString = String(data: compressedData.prefix(100), encoding: .utf8),
                  dataString.contains("BACKUP_DATA:") else {
                print("ERROR BackupManager: Keine gültige komprimierte Backup-Datei")
                return false
            }
            
            // Wir extrahieren den Dateinamen aus dem Header
            let components = dataString.components(separatedBy: "BACKUP_DATA:")
            if components.count > 1 {
                let filenameComponent = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let filename = filenameComponent.components(separatedBy: "\n").first ?? "restored_backup.sqlite"
                
                // Erstelle die Backup-Datei
                let backupURL = folderURL.appendingPathComponent(filename)
                
                // Schreibe die Daten ohne den Header
                let headerSize = dataString.components(separatedBy: "\n").first?.data(using: .utf8)?.count ?? 0
                let backupData = compressedData.advanced(by: headerSize)
                try backupData.write(to: backupURL)
                
                return restoreBackup(from: backupURL)
            }
            
            print("ERROR BackupManager: Fehler beim Entpacken des Backups")
            return false
        } catch {
            print("ERROR BackupManager: Fehler beim Wiederherstellen des komprimierten Backups: \(error)")
            return false
        }
    }
}
