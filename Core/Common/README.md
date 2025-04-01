# Core.Common Module (Future Implementation)

This directory contains type definitions and utilities that will form part of a proper module system in the future. Currently, these types are defined locally in each file that needs them, but the goal is to eventually refactor the project to use a proper Swift module system.

## Current Implementation

Since the module system is not yet fully set up, the files in this directory serve as reference implementations. Each view or component that needs these types currently has its own local definitions based on these reference files.

## Future Implementation

## Main Components

### Shared Types

Located in `SharedTypes.swift`, these types provide standardized definitions across the app:

- `AppAlertType`: For consistent alert handling
- `AppFileImportType`: For file import operations
- `AppImportError`: For standardized error handling

### Color Extensions

Extends SwiftUI's Color with app-specific colors for consistent UI styling.

### Module Descriptor

The `ModuleDescriptor.swift` file documents the modular architecture and dependency rules.

## Usage Guidelines

1. **Imports**: Import this module with `import Core.Common`

2. **Type Usage**: Use the shared types directly:
   ```swift
   @State private var alertType: AppAlertType?
   @State private var fileType: AppFileImportType = .csv
   ```

3. **Color Usage**: Use the shared color extensions for consistent styling:
   ```swift
   Text("Sample")
       .foregroundColor(.gradePrimary)
   ```

4. **Error Handling**: Use the standardized error types:
   ```swift
   catch AppImportError.invalidFile {
       // Handle error
   }
   ```

## Implementation Steps

To properly implement this module system in the future, follow these steps:

1. Configure the Xcode project to use Swift Package Manager or proper framework targets
2. Create proper module definitions with explicit imports
3. Move shared types from local definitions to the central module
4. Update imports in all files to use the proper module system

## Best Practices (Future)

1. Keep modules lightweight and focused
2. Avoid circular dependencies between modules
3. Only add types, utilities, and extensions that are truly shared
4. Maintain backward compatibility when making changes
5. Document all public APIs thoroughly

## Current Files Structure

```
Core/Common/
├── SharedTypes.swift         // Reference implementation for shared types
├── ModuleDescriptor.swift    // Future module architecture documentation
└── README.md                 // Implementation guidelines (this file)
```