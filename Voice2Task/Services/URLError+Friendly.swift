import Foundation

extension URLError {
    var friendlyMessage: String {
        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            "No hay conexión a internet. Revisa tu red e inténtalo de nuevo."
        case .timedOut:
            "La solicitud tardó demasiado. Inténtalo de nuevo."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            "No se pudo conectar con el servidor."
        default:
            "Error de red: \(localizedDescription)"
        }
    }
}
