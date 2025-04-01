// SharedTypes.swift
// Core shared type definitions for hero4 app
// This file contains common types used across multiple modules

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Alert Types

/// Common alert type used throughout the application
public enum AppAlertType: Identifiable {
    case info
    case error(String)
    case delete
    case archive
    case classChange
    
    public var id: Int {
        switch self {
        case .info: return 0
        case .error: return 1
        case .delete: return 2
        case .archive: return 3
        case .classChange: return 4
        }
    }
}

// MARK: - Import Types

/// Import file types supported by the application
public enum AppFileImportType {
    case csv
    case excel
    
    public var allowedContentTypes: [UTType] {
        switch self {
        case .csv:
            return [UTType.commaSeparatedText]
        case .excel:
            return [UTType.spreadsheet]
        }
    }
    
    public var description: String {
        switch self {
        case .csv:
            return "CSV"
        case .excel:
            return "Excel"
        }
    }
}

// MARK: - Import Errors

/// Import operation errors
public enum AppImportError: Error, LocalizedError {
    case accessDenied
    case invalidFile
    case noData
    case parseError(String)
    case invalidHeader
    case missingFirstName
    case missingLastName
    case duplicateEntry(String)
    case classLimitReached
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Zugriff auf Datei verweigert."
        case .invalidFile:
            return "Ungültiges Dateiformat."
        case .noData:
            return "Keine Daten in der Datei gefunden."
        case .parseError(let details):
            return "Fehler beim Parsen der Datei: \(details)"
        case .invalidHeader:
            return "Ungültige oder fehlende Spaltenüberschriften."
        case .missingFirstName:
            return "Vorname fehlt."
        case .missingLastName:
            return "Nachname fehlt."
        case .duplicateEntry(let name):
            return "Schüler '\(name)' existiert bereits in dieser Klasse."
        case .classLimitReached:
            return "Klassenlimit von 40 Schülern erreicht."
        case .unknownError(let error):
            return "Unbekannter Fehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - UI Colors

/// NOTE: The central color definitions have been moved to Core/Extensions/ColorExtensions.swift
/// Please import and use that file for color definitions
/// 
/// Example:
/// ```
/// import SwiftUI
/// // Use a direct import until proper module system is set up
/// // Later, we will be able to use: import Core.Extensions.ColorExtensions
/// ```