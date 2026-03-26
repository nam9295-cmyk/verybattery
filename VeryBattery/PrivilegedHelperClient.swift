import Foundation
import AppKit
import ServiceManagement

enum PrivilegedHelperError: LocalizedError {
    case helperRequiresApproval
    case helperUnavailable
    case invalidResponse
    case remoteFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .helperRequiresApproval:
            return "관리자 권한 helper가 아직 승인되지 않았습니다."
        case .helperUnavailable:
            return "Privileged helper 연결을 열지 못했습니다."
        case .invalidResponse:
            return "Privileged helper 응답이 올바르지 않습니다."
        case .remoteFailure(let message):
            return message
        }
    }
}

final class PrivilegedHelperClient {
    static let shared = PrivilegedHelperClient()
    
    private var connection: NSXPCConnection?
    
    private init() {}
    
    func runCommand(arguments: [String], completion: ((Result<String, Error>) -> Void)? = nil) {
        do {
            try ensureHelperIsReady()
            let proxy = try remoteProxy()
            proxy.runCommand(arguments) { output, errorMessage in
                DispatchQueue.main.async {
                    if let errorMessage, !errorMessage.isEmpty {
                        completion?(.failure(PrivilegedHelperError.remoteFailure(errorMessage)))
                    } else if let output {
                        completion?(.success(output))
                    } else {
                        completion?(.failure(PrivilegedHelperError.invalidResponse))
                    }
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }
    
    private func ensureHelperIsReady() throws {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: PrivilegedHelperConstants.helperPlistName)
            switch service.status {
            case .enabled:
                return
            case .requiresApproval:
                try service.register()
                throw PrivilegedHelperError.helperRequiresApproval
            case .notRegistered:
                try service.register()
            default:
                try service.register()
            }
        }
    }
    
    private func remoteProxy() throws -> BatteryPrivilegedHelperProtocol {
        if connection == nil {
            let newConnection = NSXPCConnection(
                machServiceName: PrivilegedHelperConstants.helperLabel,
                options: .privileged
            )
            newConnection.remoteObjectInterface = NSXPCInterface(with: BatteryPrivilegedHelperProtocol.self)
            newConnection.invalidationHandler = { [weak self] in
                self?.connection = nil
            }
            newConnection.interruptionHandler = { [weak self] in
                self?.connection = nil
            }
            newConnection.resume()
            connection = newConnection
        }
        
        guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ error in
            NSLog("Privileged helper XPC error: \(error.localizedDescription)")
        }) as? BatteryPrivilegedHelperProtocol else {
            throw PrivilegedHelperError.helperUnavailable
        }
        
        return proxy
    }
}
