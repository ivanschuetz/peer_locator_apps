import Foundation

public enum ServicesError: Error, Equatable {
    case general(_ message: String)
    case networking(_ message: String)
 }
