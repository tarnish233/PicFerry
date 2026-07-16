//
//  CoreManager.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/11.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Cocoa
import UniformTypeIdentifiers

@MainActor
public final class ConfigManager {
    
    // static
    public static let shared = ConfigManager()
    // instance
    
    private var historyList: [HistoryThumbnailModel]?
    
    public var firstUsage: BoolType {
        if Defaults[.firstUsage] == nil {
            Defaults[.firstUsage] = BoolType._false.rawValue
            return ._true
        } else {
            return ._false
        }
    }

    
    public func firstSetup() {
        Logger.shared.verbose("First Setup Config")

        // Cahce history list
        let _ = getHistoryList()

        var hosts = getHostItems()
        if hosts.isEmpty {
            hosts = [Host.getDefaultHost()]
        }
        // Persist the filtered list so credentials for removed providers do
        // not remain in UserDefaults after upgrading.
        if !setHostItems(items: hosts) {
            Logger.shared.error("Failed to migrate host credentials to Keychain")
        }

        if getDefaultHost() == nil, let firstHost = hosts.first {
            Defaults[.defaultHostId] = firstHost.id
        }

        if firstUsage == ._true {
            Defaults[.compressFactor] = 100
            Defaults.synchronize()
        }
    }
    
    
    public func removeAllUserDefaults() {
        // 提前取出图床配置
        let hostItems = self.getHostItems()
        let defaultHostId = Defaults[.defaultHostId]

        guard let domain = Bundle.main.bundleIdentifier else { return }
        Defaults.removePersistentDomain(forName: domain)
        Defaults.synchronize()
        
        // 清除所有用户设置后，再重新写入图床配置
        _ = setHostItems(items: hostItems)
        Defaults[.defaultHostId] = defaultHostId
    }
    
}

// MARK: - Host configuration and default host
extension ConfigManager {
    func getHostItems() -> [Host] {
        let hosts = Defaults[.hostItems] ?? []
        hosts.forEach(HostCredentialStore.hydrate)
        return hosts
    }
    
    @discardableResult
    func setHostItems(items: [Host], removesEmptyCredentials: Bool = true) -> Bool {
        let supportedItems = items.filter { HostType.allCases.contains($0.type) }
        guard supportedItems.allSatisfy({
            HostCredentialStore.save($0, removesEmptyValues: removesEmptyCredentials)
        }) else {
            Logger.shared.error("Unable to save host credentials to Keychain")
            return false
        }

        let previousItems = Defaults[.hostItems] ?? []
        Defaults[.hostItems] = supportedItems
        if let defaultHostID = Defaults[.defaultHostId],
           !supportedItems.contains(where: { $0.id == defaultHostID }) {
            Defaults[.defaultHostId] = supportedItems.first?.id
        } else if Defaults[.defaultHostId] == nil {
            Defaults[.defaultHostId] = supportedItems.first?.id
        }
        Defaults.synchronize()
        let supportedIDs = Set(supportedItems.map(\.id))
        previousItems
            .filter { !supportedIDs.contains($0.id) }
            .forEach(HostCredentialStore.remove)
        ConfigNotifier.postNotification(.changeHostItems)
        return true
    }
    
    func getDefaultHost() -> Host? {
        let hostItems = getHostItems()
        if let defaultHostID = Defaults[.defaultHostId],
           let host = hostItems.first(where: { $0.id == defaultHostID }) {
            return host
        }
        guard let firstHost = hostItems.first else { return nil }
        Defaults[.defaultHostId] = firstHost.id
        return firstHost
    }
}

extension ConfigManager {
    func getOutputType() -> OutputFormatModel? {
        let id = Defaults[.outputFormat]
        let outputFormatList = DBManager.shared.getOutputFormatList()
        guard let idx = outputFormatList.firstIndex(where: {$0.identifier == id}) else {
            return outputFormatList.first
        }
        return outputFormatList[idx]
    }
    
    func setOutputType(_ outputFormat: OutputFormatModel) {
        Defaults[.outputFormat] = outputFormat.identifier
    }
    
    func setOutputType(_ outputTypeRawValue: Int) {
        Defaults[.outputFormat] = outputTypeRawValue
    }
}

// MARK: - Upload history
extension ConfigManager {
    public var historyLimit: Int {
        get {
            let defaultLimit = 10000
            let limit = Defaults[.historyLimit]
            if (limit == nil || limit == 0) {
                return defaultLimit
            }
            return limit ?? defaultLimit
        }

        set {
            Defaults[.historyLimit] = newValue
            Defaults.synchronize()
        }
    }
    
    func getHistoryList() -> [HistoryThumbnailModel] {
        if let historyList {
            return historyList
        }

        let items = DBManager.shared.getHistoryList()
        historyList = items
        return items
    }
    
    func addHistory(_ previewModel: HistoryThumbnailModel) -> Void {
        var items = getHistoryList()
        items.insert(previewModel, at: 0)
        let offset = items.count - self.historyLimit
        if offset > 0 {
            // Because the results of the query are already sorted backwards, the first is the last
            items.removeLast(offset)
        }
        historyList = items
        if offset > 0 {
            DBManager.shared.deleteHositoryFirst(offset)
        }
        if DBManager.shared.insertHistory(previewModel) {
            Logger.shared.info("上传历史已保存")
        }
        ConfigNotifier.postNotification(.updateHistoryList)
    }
    
    func clearHistoryList() -> Void {
        historyList = []
        DBManager.shared.clearHistory()
        ConfigNotifier.postNotification(.updateHistoryList)
    }
}

// MARK: - Compression ratio of compressed images before upload
extension ConfigManager {
    var compressFactor: Int {
        get {
            return Defaults[.compressFactor] ?? 100
        }
        
        set {
            Defaults[.compressFactor] = newValue
            Defaults.synchronize()
        }
    }
}
// MARK: - Import, Export host configuretion
extension ConfigManager {
    func importHosts() {
        Logger.shared.verbose("导入图床配置")

        NSApp.activate(ignoringOtherApps: true)
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowedContentTypes = [UTType.json]
        
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                guard let url = openPanel.url,
                    let data = NSData(contentsOfFile: url.path),
                    let array = try? JSONSerialization.jsonObject(with: data as Data) as? [String]
                    else {
                        Logger.shared.error("导入图床配置失败")
                        NotificationExt.shared.postImportErrorNotice()
                        return
                }
                let hostItems = array.compactMap(Host.deserialize)
                if hostItems.count == 0 {
                    Logger.shared.error("导入图床配置失败")
                    NotificationExt.shared.postImportErrorNotice()
                    return
                }
                
                // choose import method
                
                let alert = NSAlert()
                
                alert.messageText = "Import host configuration".localized
                alert.informativeText = "⚠️ Please choose import method, merge or overwrite?".localized
                
                alert.addButton(withTitle: "merge".localized).refusesFirstResponder = true
                
                alert.addButton(withTitle: "⚠️ overwrite".localized).refusesFirstResponder = true
                
                let modalResult = alert.runModal()
                
                switch modalResult {
                case .alertFirstButtonReturn:
                    // current Items
                    var currentHostItems = ConfigManager.shared.getHostItems()
                    for host in hostItems {
                        let isContains = currentHostItems.contains(where: {item in
                            return item == host
                        })
                        if (!isContains) {
                            currentHostItems.append(host)
                        }
                    }
                    guard ConfigManager.shared.setHostItems(
                        items: currentHostItems,
                        removesEmptyCredentials: false
                    ) else {
                        NotificationExt.shared.postImportErrorNotice("Unable to save credentials to Keychain".localized)
                        return
                    }

                    Logger.shared.verbose("导入图床配置成功: \(currentHostItems.count)")
                    NotificationExt.shared.postImportSuccessfulNotice()
                case .alertSecondButtonReturn:
                    guard ConfigManager.shared.setHostItems(
                        items: hostItems,
                        removesEmptyCredentials: false
                    ) else {
                        NotificationExt.shared.postImportErrorNotice("Unable to save credentials to Keychain".localized)
                        return
                    }

                    Logger.shared.verbose("导入图床配置成功: \(hostItems.count)")
                    NotificationExt.shared.postImportSuccessfulNotice()
                default:
                    Logger.shared.verbose("取消导入图床配置")
                    print("Cancel Import")
                }
            }
        }
    }
    
    func exportHosts() {
        Logger.shared.verbose("导出图床配置")
        let hostItems = ConfigManager.shared.getHostItems()
        if hostItems.count == 0 {
            Logger.shared.warn("没有可导出的图床配置")
            NotificationExt.shared.postExportErrorNotice("No exportable hosts!".localized)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let credentialAlert = NSAlert()
        credentialAlert.messageText = "Export host configuration".localized
        credentialAlert.informativeText = "Tokens are stored in Keychain. Export without tokens is recommended; including them creates a plaintext credentials file.".localized
        credentialAlert.addButton(withTitle: "Export without tokens".localized)
        credentialAlert.addButton(withTitle: "Include tokens".localized)
        credentialAlert.addButton(withTitle: "Cancel".localized)

        let includesSecrets: Bool
        switch credentialAlert.runModal() {
        case .alertFirstButtonReturn:
            includesSecrets = false
        case .alertSecondButtonReturn:
            includesSecrets = true
        default:
            return
        }

        let savePanel = NSSavePanel()
        savePanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory().appendingPathComponent(path: "Documents"))
        savePanel.nameFieldStringValue = "PicFerry_hosts.json"
        savePanel.allowsOtherFileTypes = false
        savePanel.isExtensionHidden = true
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [UTType.json]
        
        savePanel.begin { (result) -> Void in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                
                guard let url = savePanel.url else {
                    Logger.shared.error("导出图床配置失败")
                    NotificationExt.shared.postImportErrorNotice()
                    return
                }
                
                let hostStrArr = hostItems.map { hostItem in
                    hostItem.serialize(includeSecrets: includesSecrets)
                }
                if (!JSONSerialization.isValidJSONObject(hostStrArr)) {
                    Logger.shared.error("导出图床配置失败")
                    NotificationExt.shared.postImportErrorNotice()
                    return
                }
                do {
                    let data = try JSONSerialization.data(withJSONObject: hostStrArr, options: .prettyPrinted)
                    try data.write(to: url, options: .atomic)
                    NotificationExt.shared.postExportSuccessfulNotice()
                    Logger.shared.verbose("导出图床配置成功")
                } catch {
                    Logger.shared.error("导出图床配置失败: \(error.localizedDescription)")
                    NotificationExt.shared.postExportErrorNotice()
                }
            }
        }
    }
}
