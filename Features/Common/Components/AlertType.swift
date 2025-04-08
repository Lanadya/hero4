// AlertType.swift - Template for future module implementation
import Foundation
import SwiftUI

/*
 This file serves as a template for a future implementation of a shared AlertType
 when a proper module system is set up. Currently, each file that needs AlertType
 defines its own enum locally to avoid module import issues.
 
 USAGE TEMPLATE:
 
 ```swift
 // Local enum for alert handling until proper module system is set up
 enum AlertType: Identifiable {
     case info
     case error(String)
     case delete
     case archive
     case classChange
     
     var id: Int {
         switch self {
         case .info: return 0
         case .error: return 1
         case .delete: return 2
         case .archive: return 3
         case .classChange: return 4
         }
     }
 }
 ```
 
 In the future, this will be replaced by a proper module import:
 `import Core.Common` or similar.
*/
