import Foundation

enum PrivilegedHelperConstants {
    static let helperLabel = "com.verygood.VeryBattery.PrivilegedHelper"
    static let helperPlistName = "com.verygood.VeryBattery.PrivilegedHelper.plist"
}

@objc protocol BatteryPrivilegedHelperProtocol {
    func runCommand(_ arguments: [String], withReply reply: @escaping (String?, String?) -> Void)
}
