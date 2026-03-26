#if HELPER_TOOL
import Foundation

final class VeryBatteryPrivilegedHelper: NSObject, NSXPCListenerDelegate, BatteryPrivilegedHelperProtocol {
    private let listener = NSXPCListener(machServiceName: PrivilegedHelperConstants.helperLabel)
    private let allowedCommands = Set(["maintain", "charging", "adapter", "charge", "discharge", "status"])
    
    func run() {
        listener.delegate = self
        listener.resume()
        RunLoop.current.run()
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: BatteryPrivilegedHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func runCommand(_ arguments: [String], withReply reply: @escaping (String?, String?) -> Void) {
        guard let command = arguments.first, allowedCommands.contains(command) else {
            reply(nil, "허용되지 않은 배터리 명령입니다.")
            return
        }
        
        guard let batteryExecutablePath = batteryExecutablePath() else {
            reply(nil, "앱 번들 내부 battery 실행 파일을 찾지 못했습니다.")
            return
        }
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: batteryExecutablePath)
        task.arguments = arguments
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            if task.terminationStatus == 0 {
                reply(output, nil)
            } else {
                reply(nil, output.isEmpty ? "Privileged helper 실행에 실패했습니다." : output)
            }
        } catch {
            reply(nil, error.localizedDescription)
        }
    }
    
    private func batteryExecutablePath() -> String? {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let contentsURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let batteryURL = contentsURL.appendingPathComponent("Resources/battery")
        let path = batteryURL.path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}

@main
struct VeryBatteryPrivilegedHelperMain {
    static func main() {
        let helper = VeryBatteryPrivilegedHelper()
        helper.run()
    }
}
#endif
