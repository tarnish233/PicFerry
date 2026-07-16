//
//  PicFerryCli.swift
//  PicFerry
//
//  Created by Svend Jin on 2019/12/26.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Cocoa

enum UploadSourceType {
    case normal
    case cli
}

enum CliInvocation {
    case gui
    case upload([String])
    case exit(Int32)
}

@MainActor
final class Cli {
    static let shared = Cli()
    
    private var cliKit: CommandLineKit!
    private var upload: MultiStringOption!
    private var output: StringOption!
    private var silent: BoolOption!
    private var help: BoolOption!
    private var version: BoolOption!
    
    private var allPathList: [String] = []
    private var allDataList: [Any] = []
    private var progress: Int = 0
    
    private var resultUrls: [String] = []
    
    func parseInvocation() -> CliInvocation {
        var arguments = CommandLine.arguments
        if let invocationName = ProcessInfo.processInfo.environment["PICFERRY_CLI_NAME"],
           !invocationName.isEmpty {
            arguments[0] = invocationName
        }
        guard arguments.count > 1 else { return .gui }
        
        cliKit = CommandLineKit(arguments: arguments)
        
        allPathList = []
        allDataList = []
        resultUrls = []
        progress = 0
        
        upload = MultiStringOption(shortFlag: "u", longFlag: "upload", helpMessage: "Path and URL of the file to upload".localized)
        output = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Output url format".localized)
        silent = BoolOption(shortFlag: "s", longFlag: "silent", helpMessage: "Turn off error message output".localized)
        help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Print this help message".localized)
        version = BoolOption(shortFlag: "v", longFlag: "version", helpMessage: "Print the PicFerry version".localized)
        cliKit.addOptions(upload, output, silent, help, version)
        do {
            try cliKit.parse(strict: true)
        } catch {
            cliKit.printUsage(error)
            return .exit(EX_USAGE)
        }

        if help.value {
            cliKit.printUsage()
            return .exit(EX_OK)
        }

        if version.value {
            Console.write("PicFerry \(getAppVersionString())")
            return .exit(EX_OK)
        }
        
        guard let paths = upload.value, !paths.isEmpty else {
            cliKit.printUsage()
            return .exit(EX_USAGE)
        }
        return .upload(paths)
    }
}

// MARK: - Upload
extension Cli {
    /// start upload
    /// - Parameter paths: file paths or URLs
    func startUpload(_ paths: [String]) {
        allPathList = paths
        
        for path in paths {
            let decodePath = path.urlDecoded()
            if decodePath.isAbsolutePath && FileManager.fileIsExists(path: decodePath) {
                allDataList.append(URL(fileURLWithPath: decodePath))
            } else if let fileUrl = URL(string: path), let data = try? Data(contentsOf: fileUrl)  {
                allDataList.append(data)
            } else {
                allDataList.append(path)
            }
        }
        
        var totalPathsCount = "Total paths count".localized
        totalPathsCount = totalPathsCount.replacingOccurrences(of: "{count}", with: "\(allDataList.count)")
        Console.write(totalPathsCount)
        
        // start upload
        Console.write("Uploading ...")
        (NSApplication.shared.delegate as? AppDelegate)?.uploadFiles(allDataList, .cli)
    }
    
    
    /// Upload progress
    /// - Parameter url: current url
    func uploadProgress(_ url: String) {
        var outputUrl = ""
        if let output = output?.value?.lowercased() {
            var formatUrl = url
            if Defaults[.outputFormatEncoded] {
                formatUrl = url.urlEncoded()
            }
            var filename = url.lastPathComponent.deletingPathExtension.trim()
            let tempArr = filename.components(separatedBy: .whitespaces).map{ $0.trim() }.filter{ !$0.isEmpty }
            filename = tempArr.joined(separator: "")
            switch output {
            case "url":
                outputUrl = formatUrl
                break
            case "html":
                outputUrl = "<img src='\(formatUrl)' alt='\(filename)'/>"
                break
            case "md":
                outputUrl = "![\(filename)](\(formatUrl))"
                break
            case "markdown":
                outputUrl = "![\(filename)](\(formatUrl))"
                break
            default:
                outputUrl = OutputFormatModel.formatUrl(url, outputFormat: nil)
            }
        } else {
            outputUrl = OutputFormatModel.formatUrl(url, outputFormat: nil)
        }
        
        resultUrls.append(outputUrl)
        progress += 1
        Console.write("Uploading \(progress)/\(allDataList.count)")
    }
    
    /// Upload error
    /// - Parameter errorMessage
    func uploadError(_ errorMessage: String? = nil) {
        if silent.value {
            resultUrls.append(allPathList[progress])
        } else {
            resultUrls.append(errorMessage ?? "Invalid file path".localized)
        }
        progress += 1
        Console.write("Uploading \(progress)/\(allDataList.count)")
    }
    
    
    /// all task was uploaded
    func uploadDone() {
        Console.write("Output URL:")
        
        Console.write(resultUrls.joined(separator: "\n"))
        DBManager.shared.close()
        exit(EX_OK)
    }
}
