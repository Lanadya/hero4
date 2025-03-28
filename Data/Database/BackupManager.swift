//
//  BackupManager.swift
//  hero4
//
//  Created by Nina Klee on 26.03.25.
//


import Foundation
import GRDB

class BackupManager {
    static let shared = BackupManager()

    private init() {}

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
}
