import SwiftUI
import AppKit

@main
struct VeryBatteryApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            // 전달받은 커스텀 아이콘 자산 적용
            Image("CustomMenuBarIcon")
        }
        .menuBarExtraStyle(.window) // 팝업 창 스타일로 지정
    }
}

