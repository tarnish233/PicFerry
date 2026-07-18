//
//  AppDelegate.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/7.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import ScriptingBridge
import KeyboardShortcuts
import UniformTypeIdentifiers

@NSApplicationMain
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    /* 状态栏菜单 */
    var statusItem: NSStatusItem? = nil
    private lazy var statusMenuController = StatusMenuController(appDelegate: self)
    private var statusFeedbackResetTask: Task<Void, Never>?
    
    // 是否正在上传
    var uploading = false
    // 需要上传的文件
    var needUploadFiles = [Any]()
    // 上传成功的url
    var resultUrls = [String]()
    var draggingData: Data?
    
    // MARK: - Cli Support
    // 上传来源
    var uploadSourceType: UploadSourceType! = .normal
    
    lazy var preferencesWindowController: PreferencesWindowController = {
        PreferencesWindowController.make()
    }()
    
    lazy var screenshotHelpWindowController: ScreenshotAuthorizationHelpWindowController = {
        ScreenshotAuthorizationHelpWindowController.make()
    }()
    
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        Logger.shared.verbose("Application will finish launching...")
        
        switch Cli.shared.parseInvocation() {
        case .gui:
            break
        case .upload(let paths):
            Logger.shared.verbose("The application runs as a cli")
            Cli.shared.startUpload(paths)
            return
        case .exit(let status):
            exit(status)
        }
        
        // Set status bar icon and progress icon
        setupStatusBar()
        setupKeyboardShortcuts()
        
        // Request notification permission
        NotificationExt.requestAuthorization()
        
        Logger.shared.verbose("Listening scheme")
        // Add URL scheme listening
        NSAppleEventManager.shared().setEventHandler(self, andSelector:#selector(handleGetURLEvent(event:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.shared.verbose("Application did finish launching...")

        Logger.shared.info("System Version: \(getModelIdentifier())(\(getSystemVersionString())) - App Version:\(getAppVersionString())")
        
        // Insert code here to initialize your application
        ConfigManager.shared.firstSetup()

        // 检查是否可以从子目录方案升级到根目录方案
        DiskPermissionManager.shared.tryUpgradeToRootDirectoryPermission()

        // 每天最多一次的后台静默检查更新（仅 GUI 模式）
        if statusItem != nil {
            Task { @MainActor in
                await UpdateChecker.shared.checkForUpdatesInBackgroundIfNeeded()
            }
        }

    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.verbose("Application will terminate...")
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue{
            Logger.shared.verbose("收到来自 URLScheme 的上传请求: \(urlString)")
            URLSchemeExt.shared.handleURL(urlString)
        } else {
            Logger.shared.warn("收到来自 URLScheme 的上传请求: 无效参数")
        }
    }
}
// MARK: - Statusbar
extension AppDelegate {
    
    func setupStatusBar() {
        Logger.shared.verbose("Setup status bar")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setStatusBarIcon()
        registerStatusBarEvents()
    }
    
    private func registerStatusBarEvents() {
        guard let statusItem = statusItem else {
            return
        }
        if let button = statusItem.button {
            
            button.window?.delegate = self
            
            button.window?.registerForDraggedTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")])
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // 注册拖拽文件格式支持。使其支持浏览器拖拽的URL、tiff。以及Safari 有些情况(例如，百度搜图，在默认搜索列表。不进入详情时)下拖拽的时候获取到的是图片URL字符串
            button.window?.registerForDraggedTypes([.URL, .fileURL, .string, .html])
        }
    }
    
    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp, uploading {
            uploadCancel()
            return
        }

        guard let statusItem else { return }
        statusMenuController.refreshMenu()
        statusItem.menu = statusMenuController.menu
        statusItem.button?.performClick(self)
        statusItem.menu = nil
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .selectFileShortcut) { [weak self] in
            self?.selectFile()
        }
        KeyboardShortcuts.onKeyUp(for: .pasteboardShortcut) { [weak self] in
            self?.uploadByPasteboard()
        }
        KeyboardShortcuts.onKeyUp(for: .screenshotShortcut) { [weak self] in
            self?.screenshotAndUpload()
        }
    }
    
    func setStatusBarIcon() {
        cancelStatusFeedbackReset()
        showDefaultStatusBarIcon()
    }

    private func showDefaultStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let icon = statusBarSymbol(named: "arrow.up.square", description: "PicFerry")
            ?? statusBarSymbol(named: "arrow.up", description: "PicFerry")
            ?? NSImage(named: "statusIcon")
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "PicFerry"
        button.setAccessibilityLabel("PicFerry")
    }

    private func statusBarSymbol(named name: String, description: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func showStatusBarFeedback(symbolName: String, message: String) {
        cancelStatusFeedbackReset()
        guard let button = statusItem?.button else { return }

        button.image = statusBarSymbol(named: symbolName, description: message)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = message
        button.setAccessibilityLabel(message)

        statusFeedbackResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, !self.uploading else { return }
            self.statusFeedbackResetTask = nil
            self.showDefaultStatusBarIcon()
        }
    }

    private func cancelStatusFeedbackReset() {
        statusFeedbackResetTask?.cancel()
        statusFeedbackResetTask = nil
    }
}

// MARK: - 上传方式选择
extension AppDelegate {
    
    // 选择文件上传
    @objc func selectFile() {
        Logger.shared.info("选择文件上传")
        
        if self.uploading {
            Logger.shared.warn("当前上传任务未结束")
            NotificationExt.shared.postUplodingNotice()
            return
        }
        
        let fileExtensions = BaseUploader.getFileExtensions()
        
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        if fileExtensions.count > 0 {
            openPanel.allowedContentTypes = fileExtensions.compactMap { UTType(filenameExtension: $0) }
        }
        
        openPanel.begin { (result) -> Void in
            openPanel.close()
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                Logger.shared.info("选择文件文件数：\(openPanel.urls.count)")
                self.uploadFiles(openPanel.urls)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // 从剪切板上传
    @objc func uploadByPasteboard() {
        Logger.shared.info("从剪切板上传")
        
        if self.uploading {
            Logger.shared.warn("当前上传任务未结束")
            NotificationExt.shared.postUplodingNotice()
            return
        }
        
        Logger.shared.info("剪切板上传格式:\(NSPasteboard.general.types?.first?.rawValue ?? "")")
        
        if let filenames = NSPasteboard.general.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            let fileExtensions = BaseUploader.getFileExtensions()
            var urls = [URL]()
            
            for path in filenames {
                if (fileExtensions.count == 0 || fileExtensions.contains(path.pathExtension.lowercased())) {
                    urls.append(URL(fileURLWithPath: path))
                }
            }
            
            
            Logger.shared.info("剪切板上传文件，获取到文件数：\(urls.count)")
            
            if urls.count > 0 {
                Logger.shared.info("剪切板上传文件数：\(urls.count)")
                self.uploadFiles(urls)
            } else {
                Logger.shared.warn("剪切板文件格式不支持")
                NotificationExt.shared.postUploadErrorNotice("File format not supported!".localized)
            }
            
        } else if let imageData = imageDataFromPasteboard() {
            uploadFiles([imageData])
        } else {
            Logger.shared.info("剪切板上传其他格式")
            if let urlStr = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string) {
                if let url = URL(string: urlStr.urlEncoded()), let data = try? Data(contentsOf: url)  {
                    Logger.shared.info("剪切板上传其他格式，获取到 Data")
                    self.uploadFiles([data])
                }
            }
        }
        
    }
    
    
    // 截图上传
    @objc func screenshotAndUpload() {
        Logger.shared.info("截图上传")
        
        if self.uploading {
            Logger.shared.warn("当前上传任务未结束")
            NotificationExt.shared.postUplodingNotice()
            return
        }
        
        Logger.shared.info("使用 macOS 自带截图工具截图")

        guard ScreenUtil.screeningRecordPermissionCheck() else {
            Logger.shared.warn("无截图权限，申请截图权限并弹出帮助界面")
            ScreenUtil.requestRecordScreenPermissions()
            screenshotHelpWindowController.showWindow(self)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let pasteboardChangeCount = NSPasteboard.general.changeCount
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]
        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                guard process.terminationStatus == 0,
                      NSPasteboard.general.changeCount != pasteboardChangeCount,
                      let imageData = self?.imageDataFromPasteboard() else {
                    Logger.shared.info("用户取消截图或截图数据不可用")
                    return
                }
                self?.uploadFiles([imageData])
            }
        }

        do {
            try process.run()
        } catch {
            Logger.shared.error("无法启动系统截图工具：\(error.localizedDescription)")
            NotificationExt.shared.postUploadErrorNotice(error.localizedDescription)
        }
    }

    private func imageDataFromPasteboard() -> Data? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) {
            return data
        }
        if let data = pasteboard.data(forType: .jpeg) {
            return data
        }
        if let data = pasteboard.data(forType: .tiff) {
            return data.convertImageData(.jpeg)
        }
        return nil
    }
}

// MARK: - Drag and drop file upload
extension AppDelegate: NSWindowDelegate, NSDraggingDestination {
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        self.draggingData = sender.draggedFromBrowserData
        
        if sender.draggedFileUrls.count > 0 || draggingData != nil || sender.draggedFromBrowserUrl != nil {
            if let statusItem = statusItem, let button = statusItem.button {
                button.image = NSImage(named: "uploadIcon")
            }
            return .copy
        }
        return .generic
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Logger.shared.info("拖拽到图标上传: \(sender.draggedFileUrls.count)")
        
        if sender.draggedFileUrls.count > 0 || self.draggingData != nil || sender.draggedFromBrowserUrl != nil {
            self.setStatusBarIcon()
            if sender.draggedFileUrls.count > 0 {
                self.uploadFiles(sender.draggedFileUrls)
                return true
            } else if let imageData = self.draggingData {
                self.uploadFiles([imageData])
                self.draggingData = nil
                return true
            } else if let url = sender.draggedFromBrowserUrl {
                self.uploadFiles([url])
                return true
            }
        }
        return false
    }
    
    func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    func draggingExited(_ sender: NSDraggingInfo?) {
        self.setStatusBarIcon()
    }
    
    func draggingEnded(_ sender: NSDraggingInfo) {
    }
    
}

// 上传方法
extension AppDelegate {
    // 解析以 , 分割的多个文件路径并上传
    func uploadFilesFromPaths(_ pathStr: String) {
        let paths = pathStr.split(separator: Character(","))

        Logger.shared.verbose("解析到 \(paths.count) 个文件路径")
        
        let fileExtensions = BaseUploader.getFileExtensions()
        var urls = [URL]()
        
        for path in paths {
            let sPath = String(path)
            let url = URL(fileURLWithPath: sPath)
            
            if (fileExtensions.count == 0 || fileExtensions.contains(url.pathExtension.lowercased())) {
                urls.append(url)
            }
        }
        
        if (urls.count == 0) {
            Logger.shared.error("文件格式不支持-\(pathStr)")
            NotificationExt.shared.postUploadErrorNotice("File format not supported!".localized)
            return
        }
        
        self.uploadFiles(urls)
    }
    
    // 上传多个文件，所有上传方式的入口
    func uploadFiles(_ files: [Any], _ uploadSourceType: UploadSourceType? = .normal,
                     file: StaticString = #file,
                     function: StaticString = #function,
                     line: UInt = #line) {
        
        Logger.shared.info("执行上传操作", file: file, function: function, line: line)
        
        var uploadFiles = files
        
        if let urls = files as? [URL] {
            // 如果是文件路径，处理文件夹
            var uploadUrls: [URL] = []
            for url in urls {
                let path = url.path
                
                if FileManager.directoryIsExists(path: path) {
                    let directoryName = path.lastPathComponent
                    let enumerator = FileManager.default.enumerator(atPath: path)
                    while let filename = enumerator?.nextObject() as? String {
                        let subPath = path.appendingPathComponent(path: filename)
                        if FileManager.directoryIsExists(path: subPath) {
                            continue
                        }
                        if !BaseUploader.checkFileExtensions(fileExtensions: BaseUploader.getFileExtensions(), fileExtension: filename.pathExtension) {
                            continue
                        }
                        let subDirectoryPath = filename.deletingLastPathComponent
                        let directoryPath = directoryName.appendingPathComponent(path: subDirectoryPath)
                        var subUrl = URL(fileURLWithPath: subPath)
                        subUrl._uploadFolderPath = directoryPath
                        uploadUrls.append(subUrl)
                    }
                } else {
                    uploadUrls.append(url)
                }
            }
            uploadFiles = uploadUrls
        }
        
        self.uploadSourceType = uploadSourceType
        
        self.needUploadFiles = uploadFiles
        self.resultUrls.removeAll()
        
        if self.needUploadFiles.count == 0 {
            // MARK: - Cli Support
            if self.uploadSourceType == UploadSourceType.cli {
                exit(EX_OK)
            }
            return
        }

        // 开始磁盘授权访问
        _ = DiskPermissionManager.shared.startDirectoryAccessing()
        
        // 检查是否保存了用于命令行等外部文件来源的目录授权。
        if !DiskPermissionManager.shared.checkDirectoryAuthorizationStatus() {
            Logger.shared.warn("未找到目录访问授权；沙盒外文件可能无法通过命令行上传")
        }
        
        self.uploading = true
        self.tickFileToUpload()
    }
    
    // 开始上传文件队列中的第一个文件，如果所有文件上传完成则表示当前上传任务结束
    func tickFileToUpload() {
        if self.needUploadFiles.count == 0 {
            // done
            uploadDone()
        } else {
            // next file
            let firstFile = self.needUploadFiles.removeFirst()
            if let fileURL = firstFile as? URL {
                if !FileManager.default.isReadableFile(atPath: fileURL.path) {
                    NotificationExt.shared.postFileNoAccessNotice()
                    tickFileToUpload()
                    return
                }
                BaseUploader.upload(url: fileURL)
            } else if let fileData = firstFile as? Data {
                BaseUploader.upload(data: fileData)
            } else {
                // MARK: - Cli Support
                if self.uploadSourceType == UploadSourceType.cli {
                    Cli.shared.uploadError()
                }
                tickFileToUpload()
            }
        }
    }
    
    ///
    /// 上传成功时被调用
    ///
    func uploadCompleted(url: String) {
        self.setStatusBarIcon()
        self.resultUrls.append(url)
        
        // MARK: - Cli Support
        if self.uploadSourceType == UploadSourceType.cli {
            Cli.shared.uploadProgress(url)
        }
        
        self.tickFileToUpload()
    }
    
    ///
    /// 上传失败时被调用
    ///
    func uploadFaild(errorMsg: String?, detailMsg: String? = nil,
                     file: StaticString = #file,
                     function: StaticString = #function,
                     line: UInt = #line) {
        
        let displayError = [errorMsg, detailMsg]
            .compactMap { message -> String? in
                guard let message,
                      !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return message
            }
            .first ?? "Upload failed".localized

        var logMsg = "上传失败：\(displayError)"
        if let detailMsg = detailMsg {
            logMsg = "\(logMsg): \(detailMsg))"
        }
        Logger.shared.error(logMsg, file: file, function: function, line: line)

        showStatusBarFeedback(
            symbolName: "exclamationmark.triangle.fill",
            message: "Upload failed".localized
        )
        // MARK: - Cli Support
        if self.uploadSourceType == UploadSourceType.cli {
            Cli.shared.uploadError(displayError)
        } else {
            NotificationExt.shared.postUploadErrorNotice(displayError)
        }
        
        self.tickFileToUpload()
    }
    
    func uploadStart() {
        self.setStatusBarIcon()
    }
    
    func uploadCancel() {
        Logger.shared.warn("取消上传")
        self.setStatusBarIcon()
        BaseUploader.cancelUpload()
        self.needUploadFiles.removeAll()
        self.resultUrls.removeAll()
        self.uploading = false
    }
    
    func uploadDone() {
        Logger.shared.info("上传任务结束：\(self.resultUrls.joined(separator: " | "))")
        
        // 停止磁盘授权访问
        DiskPermissionManager.shared.stopDirectoryAccessing()
        
        self.uploading = false
        // MARK: - Cli Support
        if uploadSourceType == UploadSourceType.cli {
            Cli.shared.uploadDone()
        } else {
            if self.resultUrls.count > 0 {
                let outputStr = self.copyUrls(urls: self.resultUrls)
                NotificationExt.shared.postUploadSuccessfulNotice(outputStr)
                showStatusBarFeedback(
                    symbolName: "checkmark.circle.fill",
                    message: "Uploaded successfully".localized
                )
            }
        }
        
        self.resultUrls.removeAll()
    }
    
    func copyUrls(urls: [String]) -> String {
        Logger.shared.verbose("准备复制上传结果到剪切板->\(urls.joined(separator: ","))")

        let outputUrls = BaseUploaderUtil.formatOutputUrls(urls)
        let outputStr = outputUrls.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(outputStr, forType: .string)

        Logger.shared.verbose("复制上传结果到剪切板->\(outputStr)")
        
        return outputStr
    }
}
