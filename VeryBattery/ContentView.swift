import SwiftUI
import Foundation

struct ContentView: View {
    @State private var currentLimit = 100

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
        }
        .frame(width: 270)
        // 변경 시 백그라운드 명령어 바로 실행
        .onChange(of: currentLimit) { oldValue, newValue in
            executeCommand(limit: newValue)
        }
    }
    
    // 터미널 명령어를 백그라운드에서 실행하는 엔진 함수
    func executeCommand(limit: Int) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "/opt/homebrew/bin/battery maintain \(limit)"]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
        } catch {
            print("명령어 실행 오류: \(error)")
        }
    }
}
