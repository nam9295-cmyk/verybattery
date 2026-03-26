import SwiftUI
import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var currentLimit = 100
    @State private var batteryPercentage = "--%"
    @State private var batteryTemperatureText = "--.-°C"
    @State private var powerStatus = NSLocalizedString("status.checking", comment: "")
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
    @State private var isHelperApprovalAlertPresented = false
    @State private var helperAlertTitle = NSLocalizedString("helper.alert.title", comment: "")
    @State private var helperAlertMessage = NSLocalizedString("helper.alert.short", comment: "")
    @AppStorage("storedCurrentLimit") private var storedCurrentLimit = 100
    @AppStorage("storedSailingModeEnabled") private var storedSailingModeEnabled = false
    @AppStorage("storedForceDischargeEnabled") private var storedForceDischargeEnabled = false
    @AppStorage("storedThermalProtectionEnabled") private var storedThermalProtectionEnabled = false
    @AppStorage("autoFullChargeApps") private var storedAutoFullChargeApps = "[]"
    
    private let batteryMonitorTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
    private let accentColor = Color(red: 0.36, green: 0.49, blue: 0.41)
    private let batteryExecutableCandidates = ["/usr/local/bin/battery", "/opt/homebrew/bin/battery"]
    
    private func l(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 영역
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l("app.title"))
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                    Text(l("app.subtitle"))
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
                Text(l("limit.title"))
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
                Text(l("sailing.title"))
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isSailingModeEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            
            Text(l("sailing.caption"))
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            
            HStack {
                Text(l("force_discharge.title"))
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isForceDischargeEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            
            Text(l("force_discharge.caption"))
            .font(.system(size: 10, weight: .regular, design: .default))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            HStack {
                Text(l("thermal.title"))
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $isThermalProtectionEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(accentColor)
                    .help(l("thermal.help"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 2)
            
            Text(l("thermal.caption"))
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            HStack {
                Button(action: startTripCharge) {
                    Text(isPreparingForTrip ? l("trip.running") : l("trip.button"))
                        .font(.system(size: 12, weight: .medium, design: .default))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isPreparingForTrip)
                .help(l("trip.help"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l("apps.title"))
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: presentAppPicker) {
                        Label(l("apps.add"), systemImage: "plus")
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .clipShape(Capsule())
                }
                
                if autoFullChargeApps.isEmpty {
                    Text(l("apps.empty"))
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
                
                Button(l("quit.button"), action: quitApp)
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
        .alert(helperAlertTitle, isPresented: $isHelperApprovalAlertPresented) {
            Button(l("common.ok"), role: .cancel) {}
        } message: {
            Text(helperAlertMessage)
        }
        // 변경 시 백그라운드 명령어 바로 실행
        .onChange(of: currentLimit) { oldValue, newValue in
            storedCurrentLimit = newValue
            if newValue != 80 {
                resetSailingModeControl()
            }
            applyCurrentPowerPolicy()
        }
        .onChange(of: isSailingModeEnabled) { oldValue, newValue in
            storedSailingModeEnabled = newValue
            if !newValue {
                resetSailingModeControl()
            }
            applyCurrentPowerPolicy()
        }
        .onChange(of: isForceDischargeEnabled) { oldValue, newValue in
            storedForceDischargeEnabled = newValue
            handleForceDischargeToggleChange(isEnabled: newValue)
        }
        .onChange(of: autoFullChargeApps) { oldValue, newValue in
            persistAutoFullChargeApps()
            refreshRegisteredAppState()
            applyCurrentPowerPolicy()
        }
        .onChange(of: isThermalProtectionEnabled) { oldValue, newValue in
            storedThermalProtectionEnabled = newValue
            if !newValue {
                isThermalProtectionActive = false
                thermalProtectionHoldLevel = nil
            }
            applyCurrentPowerPolicy(force: true)
        }
        .onAppear {
            restorePersistedSettings()
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
    
    func restorePersistedSettings() {
        currentLimit = storedCurrentLimit
        isSailingModeEnabled = storedSailingModeEnabled
        isForceDischargeEnabled = storedForceDischargeEnabled
        isThermalProtectionEnabled = storedThermalProtectionEnabled
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
        let arguments = command.split(separator: " ").map(String.init)
        PrivilegedHelperClient.shared.runCommand(arguments: arguments) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                if case PrivilegedHelperError.helperRequiresApproval = error {
                    powerStatus = l("helper.status.approval_needed")
                    presentHelperApprovalAlert()
                } else {
                    print("Privileged helper 오류: \(error.localizedDescription)")
                    executeShellCommandLocally(arguments: arguments)
                }
            }
        }
    }
    
    func executeShellCommandLocally(arguments: [String]) {
        guard let batteryExecutablePath = resolvedBatteryExecutablePath() else {
            print("battery 실행 파일을 찾지 못했습니다.")
            return
        }
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = arguments
        task.executableURL = URL(fileURLWithPath: batteryExecutablePath)
        
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
            command = "maintain \(currentLimit) --force-discharge"
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
    
    func presentHelperApprovalAlert() {
        helperAlertTitle = l("helper.alert.title")
        helperAlertMessage = l("helper.alert.message")
        isHelperApprovalAlertPresented = true
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
                    powerStatus = isThermalProtectionActive ? l("status.thermal_active") : (isForceDischargeEnabled ? l("status.force_discharge_active") : parsedStatus.status)
                    applyCurrentPowerPolicy()
                }
            case .failure:
                DispatchQueue.main.async {
                    batteryPercentage = "--%"
                    batteryTemperatureText = "--.-°C"
                    powerStatus = l("status.failed")
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
        if let bundledPath = Bundle.main.path(forResource: "battery", ofType: nil),
           FileManager.default.isExecutableFile(atPath: bundledPath) {
            return bundledPath
        }
        
        for candidate in batteryExecutableCandidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        
        let pathOutput = runShellOutput("command -v battery").trimmingCharacters(in: .whitespacesAndNewlines)
        return pathOutput.isEmpty ? nil : pathOutput
    }
    
    func presentAppPicker() {
        let panel = NSOpenPanel()
        panel.title = l("apps.panel.title")
        panel.message = l("apps.panel.message")
        panel.prompt = l("apps.add")
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
            return ("--%", l("status.no_info"), nil)
        }
        
        let sourceLine = lines[0]
        let detailLine = lines[1]
        
        let percentage = detailLine.range(of: #"\d+%"#, options: .regularExpression)
            .map { String(detailLine[$0]) } ?? "--%"
        let level = Int(percentage.replacingOccurrences(of: "%", with: ""))
        
        let lowercasedDetail = detailLine.lowercased()
        let lowercasedSource = sourceLine.lowercased()
        
        if lowercasedDetail.contains("charging") {
            return (percentage, l("status.charging_ac"), level)
        }
        
        if lowercasedDetail.contains("discharging") {
            return (percentage, l("status.discharging_battery"), level)
        }
        
        if lowercasedDetail.contains("charged") {
            return (percentage, l("status.charged_ac"), level)
        }
        
        if lowercasedSource.contains("ac power") {
            return (percentage, l("status.ac_connected"), level)
        }
        
        if lowercasedSource.contains("battery power") {
            return (percentage, l("status.on_battery"), level)
        }
        
        return (percentage, l("status.checking_power"), level)
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
