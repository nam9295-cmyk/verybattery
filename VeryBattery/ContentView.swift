import SwiftUI
import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var currentLimit = 100
    @State private var batteryPercentage = "--%"
    @State private var batteryTemperatureText = "--.-°C"
    @State private var powerStatus = "상태 확인 중..."
    @State private var isPreparingForTrip = false
    @State private var isSailingModeEnabled = false
    @State private var isSailingChargeBlocked = false
    @State private var isForceDischargeEnabled = false
    @State private var isThermalProtectionEnabled = false
    @State private var isThermalProtectionActive = false
    @State private var thermalProtectionHoldLevel: Int?
    @State private var autoFullChargeApps: [AutoFullChargeApp] = []
    @State private var isRegisteredAppRunning = false
    @State private var lastAppliedCommand = ""
    @State private var tripChargeResetWorkItem: DispatchWorkItem?
    @AppStorage("autoFullChargeApps") private var storedAutoFullChargeApps = "[]"
    
    private let batteryMonitorTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
    private let accentColor = Color(red: 0.36, green: 0.49, blue: 0.41)
    private let batteryExecutableCandidates = ["/usr/local/bin/battery", "/opt/homebrew/bin/battery"]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 영역
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("배터리")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                    Text("Mac의 배터리 수명을 위해 충전 한도를 제어합니다.")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                Text(batteryPercentage)
                    .font(.custom("SF Mono", size: 11))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(powerStatus)
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.secondary)
                
                Text(batteryTemperatureText)
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // 순정 macOS 스타일 토글 행
            HStack {
                Text("충전 한도")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("", selection: $currentLimit) {
                    Text("80%").tag(80)
                    Text("100%").tag(100)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 110)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 4)
            
            HStack {
                Text("세일링 모드")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isSailingModeEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            
            Text("75%까지 떨어질 때까지 충전을 멈춰 배터리 스트레스를 줄입니다.")
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            
            HStack {
                Text("강제 방전 모드")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isForceDischargeEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            
            Text("어댑터 연결 중에도 전력을 차단해 배터리를 소모시킵니다.")
            .font(.system(size: 10, weight: .regular, design: .default))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            HStack {
                Text("열 보호 모드")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isThermalProtectionEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("배터리 온도가 35°C를 초과하면 어댑터 전력을 강제로 차단하여 열 손상을 방지합니다.")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            
            Text("35°C 이상에서는 충전을 잠시 멈추고, 온도가 내려가면 다시 원래 한도로 복귀합니다.")
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            HStack {
                Button(action: startTripCharge) {
                    Text(isPreparingForTrip ? "풀충전 진행 중... (타이머)" : "외출 준비 (2시간 풀충전)")
                        .font(.system(size: 12, weight: .medium, design: .default))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isPreparingForTrip)
                .help("즉시 100% 충전을 시작하고, 2시간 뒤에 자동으로 80% 유지 모드로 복귀합니다.")
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("자동 풀충전 앱 등록")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: presentAppPicker) {
                        Label("앱 추가", systemImage: "plus")
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .clipShape(Capsule())
                }
                
                if autoFullChargeApps.isEmpty {
                    Text("등록한 앱이 실행되면 자동으로 100% 충전 모드가 시작됩니다.")
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(autoFullChargeApps) { app in
                            HStack(spacing: 10) {
                                Image(nsImage: appIcon(for: app.path))
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                
                                Text(app.name)
                                    .font(.system(size: 11, weight: .medium, design: .default))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: { removeAutoFullChargeApp(app) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.bordered)
                                .tint(accentColor)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(accentColor.opacity(0.10))
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            HStack {
                Spacer()
                
                Button("종료", action: quitApp)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(width: 270)
        // 변경 시 백그라운드 명령어 바로 실행
        .onChange(of: currentLimit) { oldValue, newValue in
            if newValue != 80 {
                resetSailingModeControl()
            }
            applyCurrentPowerPolicy()
        }
        .onChange(of: isSailingModeEnabled) { oldValue, newValue in
            if !newValue {
                resetSailingModeControl()
            }
            applyCurrentPowerPolicy()
        }
        .onChange(of: isForceDischargeEnabled) { oldValue, newValue in
            handleForceDischargeToggleChange(isEnabled: newValue)
        }
        .onChange(of: autoFullChargeApps) { oldValue, newValue in
            persistAutoFullChargeApps()
            refreshRegisteredAppState()
            applyCurrentPowerPolicy()
        }
        .onChange(of: isThermalProtectionEnabled) { oldValue, newValue in
            if !newValue {
                isThermalProtectionActive = false
                thermalProtectionHoldLevel = nil
            }
            applyCurrentPowerPolicy(force: true)
        }
        .onAppear {
            loadAutoFullChargeApps()
            refreshRegisteredAppState()
            refreshBatteryStatus()
            applyCurrentPowerPolicy()
        }
        .onReceive(batteryMonitorTimer) { _ in
            refreshBatteryStatus()
        }
        .onReceive(workspaceNotificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            refreshRegisteredAppState()
            applyCurrentPowerPolicy()
        }
        .onReceive(workspaceNotificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            refreshRegisteredAppState()
            applyCurrentPowerPolicy()
        }
    }
    
    func startTripCharge() {
        tripChargeResetWorkItem?.cancel()
        isPreparingForTrip = true
        applyCurrentPowerPolicy(force: true)
        
        let resetWorkItem = DispatchWorkItem {
            isPreparingForTrip = false
            applyChargeLimit(80, force: true)
            tripChargeResetWorkItem = nil
        }
        
        tripChargeResetWorkItem = resetWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 7200, execute: resetWorkItem)
    }
    
    func applyChargeLimit(_ limit: Int, force: Bool) {
        if currentLimit != limit {
            currentLimit = limit
            return
        }
        
        if force {
            applyCurrentPowerPolicy(force: true)
        }
    }
    
    func resetSailingModeControl() {
        isSailingChargeBlocked = false
    }
    
    func handleForceDischargeToggleChange(isEnabled: Bool) {
        if isEnabled {
            resetSailingModeControl()
        }
        
        applyCurrentPowerPolicy(force: true)
    }
    
    // 터미널 명령어를 백그라운드에서 실행하는 엔진 함수
    func executeCommand(limit: Int) {
        executeShellCommand("maintain \(limit)")
    }
    
    func executeShellCommand(_ command: String) {
        guard let batteryExecutablePath = resolvedBatteryExecutablePath() else {
            print("battery 실행 파일을 찾지 못했습니다.")
            return
        }
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "\(batteryExecutablePath) \(command)"]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
        } catch {
            print("명령어 실행 오류: \(error)")
        }
    }
    
    func applyCurrentPowerPolicy(force: Bool = false) {
        let command: String
        
        if isThermalProtectionActive {
            command = "maintain \(thermalProtectionHoldLevel ?? currentLimit)"
        } else if isForceDischargeEnabled {
            command = "discharge \(currentLimit)"
        } else if isPreparingForTrip || isRegisteredAppRunning {
            command = "maintain 100"
        } else if !autoFullChargeApps.isEmpty {
            command = "maintain 80"
        } else if isSailingChargeBlocked {
            command = "charging off"
        } else {
            command = "maintain \(currentLimit)"
        }
        
        guard force || lastAppliedCommand != command else {
            return
        }
        
        lastAppliedCommand = command
        executeShellCommand(command)
    }
    
    func refreshBatteryStatus() {
        DispatchQueue.global(qos: .background).async {
            let batteryOutput = runProcess(executablePath: "/usr/bin/pmset", arguments: ["-g", "batt"])
            let temperatureOutput = runShellOutput("/usr/sbin/ioreg -rn AppleSmartBattery | /usr/bin/grep Temperature")
            
            switch batteryOutput {
            case .success(let output):
                let parsedStatus = parseBatteryOutput(output)
                let parsedTemperature = parseBatteryTemperature(temperatureOutput)
                
                DispatchQueue.main.async {
                    batteryPercentage = parsedStatus.percentage
                    batteryTemperatureText = parsedTemperature.displayText
                    handleSailingModeIfNeeded(batteryLevel: parsedStatus.level)
                    handleThermalProtectionIfNeeded(temperatureCelsius: parsedTemperature.celsius, batteryLevel: parsedStatus.level)
                    powerStatus = isThermalProtectionActive ? "🔥 열 보호 중 (전원 유지)" : parsedStatus.status
                    applyCurrentPowerPolicy()
                }
            case .failure:
                DispatchQueue.main.async {
                    batteryPercentage = "--%"
                    batteryTemperatureText = "--.-°C"
                    powerStatus = "상태 확인 실패"
                }
            }
        }
    }
    
    func handleSailingModeIfNeeded(batteryLevel: Int?) {
        guard !isForceDischargeEnabled, !isPreparingForTrip, !isRegisteredAppRunning, !isThermalProtectionActive else {
            if isSailingChargeBlocked {
                isSailingChargeBlocked = false
            }
            return
        }
        
        guard isSailingModeEnabled, currentLimit == 80, let batteryLevel else {
            if isSailingChargeBlocked {
                resetSailingModeControl()
            }
            return
        }
        
        if batteryLevel >= 80, !isSailingChargeBlocked {
            isSailingChargeBlocked = true
            return
        }
        
        if batteryLevel < 75, isSailingChargeBlocked {
            isSailingChargeBlocked = false
        }
    }
    
    func handleThermalProtectionIfNeeded(temperatureCelsius: Double?, batteryLevel: Int?) {
        guard isThermalProtectionEnabled, let temperatureCelsius else {
            if isThermalProtectionActive {
                isThermalProtectionActive = false
                thermalProtectionHoldLevel = nil
            }
            return
        }
        
        if temperatureCelsius > 35 {
            if !isThermalProtectionActive {
                thermalProtectionHoldLevel = batteryLevel
            }
            isThermalProtectionActive = true
            return
        }
        
        if temperatureCelsius <= 32, isThermalProtectionActive {
            isThermalProtectionActive = false
            thermalProtectionHoldLevel = nil
        }
    }
    
    func runProcess(executablePath: String, arguments: [String]) -> Result<String, Error> {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = arguments
        task.executableURL = URL(fileURLWithPath: executablePath)
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return .success(String(decoding: data, as: UTF8.self))
        } catch {
            print("프로세스 실행 오류: \(error)")
            return .failure(error)
        }
    }
    
    func runShellOutput(_ command: String) -> String {
        switch runProcess(executablePath: "/bin/zsh", arguments: ["-c", command]) {
        case .success(let output):
            return output
        case .failure:
            return ""
        }
    }
    
    func resolvedBatteryExecutablePath() -> String? {
        for candidate in batteryExecutableCandidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        
        let pathOutput = runShellOutput("command -v battery").trimmingCharacters(in: .whitespacesAndNewlines)
        return pathOutput.isEmpty ? nil : pathOutput
    }
    
    func presentAppPicker() {
        let panel = NSOpenPanel()
        panel.title = "자동 풀충전 앱 선택"
        panel.message = "실행 시 자동으로 100% 충전을 시작할 앱을 선택하세요."
        panel.prompt = "추가"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }
        
        let app = AutoFullChargeApp(path: selectedURL.path, name: displayName(for: selectedURL))
        guard !autoFullChargeApps.contains(where: { $0.path == app.path }) else {
            return
        }
        
        autoFullChargeApps.append(app)
        autoFullChargeApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    func removeAutoFullChargeApp(_ app: AutoFullChargeApp) {
        autoFullChargeApps.removeAll { $0.id == app.id }
    }
    
    func loadAutoFullChargeApps() {
        guard let data = storedAutoFullChargeApps.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([AutoFullChargeApp].self, from: data) else {
            autoFullChargeApps = []
            return
        }
        
        autoFullChargeApps = decoded
    }
    
    func persistAutoFullChargeApps() {
        guard let data = try? JSONEncoder().encode(autoFullChargeApps),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        
        storedAutoFullChargeApps = json
    }
    
    func refreshRegisteredAppState() {
        let runningAppPaths = Set(
            NSWorkspace.shared.runningApplications.compactMap { runningApplication in
                runningApplication.bundleURL?.path
            }
        )
        
        isRegisteredAppRunning = autoFullChargeApps.contains { runningAppPaths.contains($0.path) }
    }
    
    func displayName(for url: URL) -> String {
        if let bundle = Bundle(url: url) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
                return displayName
            }
            
            if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
                return bundleName
            }
        }
        
        return url.deletingPathExtension().lastPathComponent
    }
    
    func quitApp() {
        NSApp.terminate(nil)
    }
    
    func appIcon(for path: String) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 18, height: 18)
        return image
    }
    
    func parseBatteryOutput(_ output: String) -> (percentage: String, status: String, level: Int?) {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        
        guard lines.count >= 2 else {
            return ("--%", "상태 정보 없음", nil)
        }
        
        let sourceLine = lines[0]
        let detailLine = lines[1]
        
        let percentage = detailLine.range(of: #"\d+%"#, options: .regularExpression)
            .map { String(detailLine[$0]) } ?? "--%"
        let level = Int(percentage.replacingOccurrences(of: "%", with: ""))
        
        let lowercasedDetail = detailLine.lowercased()
        let lowercasedSource = sourceLine.lowercased()
        
        if lowercasedDetail.contains("charging") {
            return (percentage, "충전 중 | AC 전원 연결됨", level)
        }
        
        if lowercasedDetail.contains("discharging") {
            return (percentage, "방전 중 | 배터리 사용", level)
        }
        
        if lowercasedDetail.contains("charged") {
            return (percentage, "충전 완료 | AC 전원 연결됨", level)
        }
        
        if lowercasedSource.contains("ac power") {
            return (percentage, "AC 전원 연결됨", level)
        }
        
        if lowercasedSource.contains("battery power") {
            return (percentage, "배터리 사용 중", level)
        }
        
        return (percentage, "전원 상태 확인 중", level)
    }
    
    func parseBatteryTemperature(_ output: String) -> (displayText: String, celsius: Double?) {
        guard let rawValueRange = output.range(of: #"\d+"#, options: .regularExpression),
              let rawValue = Double(output[rawValueRange]) else {
            return ("--.-°C", nil)
        }
        
        let celsius = rawValue / 100.0
        return (String(format: "%.1f°C", celsius), celsius)
    }
}

struct AutoFullChargeApp: Identifiable, Codable, Hashable {
    let path: String
    let name: String
    
    var id: String { path }
}
