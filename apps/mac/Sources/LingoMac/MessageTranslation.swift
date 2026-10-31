import Foundation

/// State of the "Translate to Russian" action of one message.
enum MessageTranslation: Equatable {
    case loading
    case done(String)
    case failed(String)
}
