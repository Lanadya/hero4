// ModuleDescriptor.swift
// Defines the module structure for the hero4 app

import Foundation

/*
 Core Modules:
 - Core.Common - Shared types, utilities, and extensions
 - Core.Utils - Helper functions and constants
 - Core.Resources - Assets and resources
 - Core.Extensions - SwiftUI and Foundation extensions
 
 Data Modules:
 - Data.Models - Data model definitions
 - Data.Database - Database access and migrations
 - Data.Repositories - Data access layer
 - Data.Services - Services for data processing
 
 Feature Modules:
 - Features.Common - Shared UI components
 - Features.Students - Student management
 - Features.Timetable - Class/timetable management
 - Features.SeatingPlan - Seating plan management
 - Features.Results - Grade/results management
 - Features.Archive - Archive functionality
 
 Navigation:
 - Navigation - Main tab view and navigation logic
 
 App:
 - App - Main app entry point and state
 
 The module structure follows these dependency rules:
 1. Core modules don't depend on other modules
 2. Data modules can depend on Core modules
 3. Feature modules can depend on Core and Data modules
 4. Navigation depends on Feature modules
 5. App depends on all modules
 
 This structure ensures a clean separation of concerns and avoids circular dependencies.
 */