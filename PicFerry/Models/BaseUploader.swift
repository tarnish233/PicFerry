//
//  BaseUploader.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/6/10.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Cocoa
import Alamofire

class BaseUploader: @unchecked Sendable {

    func start() {
        Task { @MainActor in
            (NSApplication.shared.delegate as? AppDelegate)?.uploadStart()
        }
    }

    func completed(url: String, _ fileData: Data?, _ fileUrl: URL?, hostID: String? = nil) {
        guard !url.isEmpty else {
            faild(errorMsg: "Upload response did not contain a URL".localized)
            return
        }

        Task { @MainActor in
            saveHistory(url: url, fileData: fileData, fileURL: fileUrl, hostID: hostID)
            (NSApplication.shared.delegate as? AppDelegate)?.uploadCompleted(url: url)
        }
    }

    @MainActor
    private func saveHistory(url: String, fileData: Data?, fileURL: URL?, hostID: String?) {
        let sourceData = fileData ?? fileURL.flatMap { try? Data(contentsOf: $0) }
        let previewModel = HistoryThumbnailModel()
        previewModel.url = url
        previewModel.size = sourceData?.count ?? 0
        previewModel.host = hostID ?? Defaults[.defaultHostId]

        guard let sourceData,
              let image = NSImage(data: sourceData),
              image.size.width > 0,
              image.size.height > 0 else {
            ConfigManager.shared.addHistory(previewModel)
            return
        }

        let maximumPreviewSize = CGSize(width: 450, height: 600)
        let scale = min(
            maximumPreviewSize.width / image.size.width,
            maximumPreviewSize.height / image.size.height,
            1
        )
        previewModel.previewWidth = Double(image.size.width * scale)
        previewModel.previewHeight = Double(image.size.height * scale)
        previewModel.isImage = true

        let aspectRatio = image.size.width / image.size.height
        let thumbnailWidth: CGFloat = 180
        let thumbnailSize = NSSize(width: thumbnailWidth, height: thumbnailWidth / aspectRatio)
        let resizedImage = image.resizeImage(size: thumbnailSize)
        if let tiffData = resizedImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
            previewModel.thumbnailData = pngData
        } else {
            previewModel.thumbnailData = resizedImage.tiffRepresentation
        }

        ConfigManager.shared.addHistory(previewModel)
    }

    func faild(errorMsg: String? = "",
               file: StaticString = #file,
               function: StaticString = #function,
               line: UInt = #line) {
        self.faild(responseData: nil, errorMsg: errorMsg, file: file, function: function, line: line)
    }

    func faild(responseData: Data?, errorMsg: String? = nil,
               file: StaticString = #file,
               function: StaticString = #function,
               line: UInt = #line) {
        let responseStr = responseData.flatMap { String(data: $0, encoding: .utf8) }

        Task { @MainActor in
            (NSApplication.shared.delegate as? AppDelegate)?.uploadFaild(errorMsg: errorMsg, detailMsg: responseStr, file: file, function: function, line: line)
        }
    }

    /*********************************************************** static *******************************************************************/

    static func cancelUpload() {
        Session.default.session.getTasksWithCompletionHandler({ dataTasks, uploadTasks, downloadTasks in
            uploadTasks.forEach {
                $0.cancel()
            }
        })
    }

    ///
    /// 作为上传的统一入口
    /// As a unified entry point for uploads
    ///
    @MainActor
    static func upload(url: URL, _ defaultHost: Host? = nil) {
        Logger.shared.info("开始上传-fileURL方式-\(url.path)")
        guard let host = defaultHost ?? ConfigManager.shared.getDefaultHost() else {
            Logger.shared.warn("未获取到图床")
            return
        }

        let fileExtensions = BaseUploader.getFileExtensions(for: host)
        if (!BaseUploader.checkFileExtensions(fileExtensions: fileExtensions, fileExtension: url.pathExtension)) {
            let errorMsg = "\("File format not supported!".localized)\(url.pathExtension)"
            (NSApplication.shared.delegate as? AppDelegate)?.uploadFaild(errorMsg: errorMsg)
            return
        }

        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path), let fileSize = attr[FileAttributeKey.size] as? UInt64 {
            let limitSize = BaseUploader.getFileSizeLimit()
            if (!BaseUploader.checkFileSize(fileSize: fileSize, limitSize: limitSize)) {
                let errorMsg = "\("File is over the size limit! Limit:".localized)\(ByteCountFormatter.string(fromByteCount: Int64(limitSize), countStyle: .binary))"
                (NSApplication.shared.delegate as? AppDelegate)?.uploadFaild(errorMsg: errorMsg)
                return
            }
        }

        Logger.shared.info("匹配上传图床：\(host.name)(\(host.type.rawValue))")

        /* 有新的图床在这里进行判断调用 */
        switch host.type {
        case .github:
            GithubUploader.shared.upload(url, host: host)
        case .gitee:
            GiteeUploader.shared.upload(url, host: host)
        }
    }

    ///
    /// 作为上传的统一入口
    /// As a unified entry point for uploads
    ///
    @MainActor
    static func upload(data: Data, _ defaultHost: Host? = nil) {
        Logger.shared.info("开始上传-data方式")
        guard let host = defaultHost ?? ConfigManager.shared.getDefaultHost() else {
            Logger.shared.warn("未获取到图床")
            return
        }

        let limitSize = BaseUploader.getFileSizeLimit()
        if (!BaseUploader.checkFileSize(fileSize: UInt64(data.count), limitSize: limitSize)) {

            let errorMsg = "\("File is over the size limit! Limit:".localized)\(ByteCountFormatter.string(fromByteCount: Int64(limitSize), countStyle: .binary))"
            (NSApplication.shared.delegate as? AppDelegate)?.uploadFaild(errorMsg: errorMsg)
            return
        }
        Logger.shared.info("匹配上传图床：\(host.name)(\(host.type.rawValue))")

        /* 有新的图床在这里进行判断调用 */
        switch host.type {
        case .github:
            GithubUploader.shared.upload(data, host: host)
        case .gitee:
            GiteeUploader.shared.upload(data, host: host)
        }
    }

    ///
    /// 获取当前图床对应的支持文件格式
    ///
    @MainActor
    static func getFileExtensions(for requestedHost: Host? = nil) -> [String] {
        guard let host = requestedHost ?? ConfigManager.shared.getDefaultHost() else {
            return [String]()
        }

        /* 有新的图床在这里进行判断调用 */
        switch host.type {
        case .github:
            return GithubUploader.fileExtensions
        case .gitee:
            return GiteeUploader.fileExtensions
        }
    }

    ///
    /// 获取当前图床对应的文件大小限制
    ///
    static func getFileSizeLimit() -> UInt64 {
        0
    }

    static func checkFileExtensions(fileExtensions: [String], fileExtension: String) -> Bool {
        if fileExtensions.count == 0 {
            return true
        }
        let valid = fileExtensions.contains(fileExtension.lowercased())
        return valid
    }

    private static func checkFileSize(fileSize: UInt64?, limitSize: UInt64) -> Bool {
        guard let size = fileSize else {
            return true
        }

        if (limitSize <= 0) {
            return true
        }

        return size <= limitSize
    }
}

private enum UploadFolderAssociation {
    nonisolated(unsafe) static var key: UInt8 = 0
}

extension URL {
    var _uploadFolderPath: String? {
        get {
            return objc_getAssociatedObject(self, &UploadFolderAssociation.key) as? String
        }

        set {
            objc_setAssociatedObject(self, &UploadFolderAssociation.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension Data {
    var _uploadFolderPath: String? {
        get {
            return objc_getAssociatedObject(self, &UploadFolderAssociation.key) as? String
        }

        set {
            objc_setAssociatedObject(self, &UploadFolderAssociation.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
