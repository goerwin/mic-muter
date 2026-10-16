import Foundation

enum AppInfo {
    static var name: String {
        let bundle = Bundle.main
        return
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Mic Muter"
    }

    static var version: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let isDevelopment = bundle.object(forInfoDictionaryKey: "MicMuterBuildChannel") as? String == "Development"
        return isDevelopment ? "\(version) (Development)" : version
    }

    static var repositoryURL: URL? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "repositoryURL") as? String
        return raw.flatMap(URL.init(string:))
    }
}
