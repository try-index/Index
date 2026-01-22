//
//  SimulatorManager.swift
//  Index
//
//  Created by Axel Martinez on 26/11/24.
//

import SwiftUI

enum SimulatorManagerError: LocalizedError {
    case simulatorPathNotFound
    case deviceInfoNotFound
    case containerInfoNotFound
    
    var errorDescription: String? {
        switch self {
        case .simulatorPathNotFound:
            return "Could not find iOS Simulator path"
        case .deviceInfoNotFound:
            return "Could not read device information"
        case .containerInfoNotFound:
            return "Could not read container information"
        }
    }
}

class SimulatorManager: ObservableObject {
    func loadSimulators(from: URL) -> [Simulator] {
        do {
            var simulators = [Simulator]()
            
            let simulatorPath = from.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
            let deviceFolders = try FileManager.default.contentsOfDirectory(
                at: simulatorPath,
                includingPropertiesForKeys: nil
            ).filter(\.hasDirectoryPath)
            
            for deviceFolder in deviceFolders {
                let bundlesPath = deviceFolder.appendingPathComponent("data/Containers/Bundle/Application").path()
                
                if FileManager.default.fileExists(atPath: bundlesPath) {
                    let plistPath = deviceFolder.appendingPathComponent("device.plist")
                    let plistData = try Data(contentsOf: plistPath)
                    
                    if let plist = try PropertyListSerialization.propertyList(
                        from: plistData,
                        options: [],
                        format: nil
                    ) as? [String: Any] {
                        simulators.append(Simulator(
                            name: plist["name"] as? String ?? "Unknown Simulator",
                            runtime: readableRuntimeName(plist["runtime"] as? String) ?? "Unknown Runtime",
                            url: deviceFolder
                        ))
                    }
                }
            }
            
            return simulators
        } catch {
            print("Error loading simulators: \(error)")
        }
        
        return []
    }
    
    /// Converts a CoreSimulator runtime identifier to a more readable name
    func readableRuntimeName(_ runtime: String?) -> String? {
        guard let runtime else {
            return nil
        }
        
        // Split the runtime identifier into components
        let components = runtime.components(separatedBy: "com.apple.CoreSimulator.SimRuntime.")
        
        guard components.count > 1 else {
            return nil
        }
        
        // Take the second part (after the prefix)
        let runtimeIdentifier = components[1]
        
        // Regex pattern to match a string with dash-separated words
        let pattern = #"^([^-]+)-(.+)$"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: runtimeIdentifier, range: NSRange(runtimeIdentifier.startIndex..., in: runtimeIdentifier)) {
            
            // Extract the first part (before first dash)
            let firstPartRange = match.range(at: 1)
            let firstPart = (runtimeIdentifier as NSString).substring(with: firstPartRange)
            
            // Extract the rest (after first dash)
            let restRange = match.range(at: 2)
            let restPart = (runtimeIdentifier as NSString).substring(with: restRange)
            
            // Replace dashes in the rest with dots
            let transformedRest = restPart.replacingOccurrences(of: "-", with: ".")
            
            return "\(firstPart) \(transformedRest)"
        }
        
        return runtimeIdentifier
    }
    
    func getSimulatorApps(at simulatorURL: URL) -> [AppInfo] {
        var applications = [AppInfo]()
        
        do {
            let bundleFolders = try FileManager.default.contentsOfDirectory(
                at: simulatorURL.appendingPathComponent("data/Containers/Bundle/Application"),
                includingPropertiesForKeys: nil
            ).filter(\.hasDirectoryPath)
            
            let dataFolders = try FileManager.default.contentsOfDirectory(
                at: simulatorURL.appendingPathComponent("data/Containers/Data/Application"),
                includingPropertiesForKeys: nil
            ).filter(\.hasDirectoryPath)
            
            for bundleFolder in bundleFolders {
                let appIdentifier = try getAppIdentifier(from: bundleFolder)
                
                guard let appFolder = try? FileManager.default.contentsOfDirectory(
                    at: bundleFolder,
                    includingPropertiesForKeys: nil,
                    options: []
                ).filter({ $0.pathExtension == "app" }).first else {
                    break
                }
                
                var bundleDisplayName: String?
                var bundleIconInfo: IconInfo?
                
                if let infoPlist = readPlist(from: appFolder.appendingPathComponent("Info.plist")) {
                    bundleDisplayName = infoPlist["CFBundleDisplayName"] as? String ?? infoPlist["CFBundleName"] as? String
                    bundleIconInfo = extractAppIconsInfo(from: infoPlist)
                }

                var databaseFileURLs = [URL]()
                
                for dataFolder in dataFolders {
                    let dataIdentifier = try getAppIdentifier(from: dataFolder)
                    if dataIdentifier == appIdentifier {
                        databaseFileURLs.append(contentsOf: findDatabaseFiles(in: dataFolder))
                        break
                    }
                }
                
                let iconFiles = try findIconFiles(matching: bundleIconInfo, in: appFolder)
                
                if !databaseFileURLs.isEmpty {
                    applications.append(AppInfo(
                        id: appFolder.path(),
                        name: bundleDisplayName ?? "Unknown app name",
                        fileURLs: databaseFileURLs,
                        icon: loadIcons(from: iconFiles)
                    ))
                }
            }
        } catch {
            print("Error finding database files: \(error)")
        }
        
        return applications
    }
    
    private func getAppIdentifier(from appFolder: URL) throws -> String? {
        let containerPath = appFolder.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        
        guard let containerInfo = NSDictionary(contentsOf: containerPath) else {
            throw SimulatorManagerError.containerInfoNotFound
        }
        
        return containerInfo["MCMMetadataIdentifier"] as? String
    }
    
    private func findIconFiles(matching iconInfo: IconInfo?, in directoryURL: URL) throws-> [URL] {
        guard let iconInfo = iconInfo else {
            return []
        }
        
        // Get the list of file names in the directory
        let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        
        // Filter file URLs based on whether their names contain any of the search strings
        return fileURLs.filter({ fileURL in
            if let primaryIconFile = iconInfo.primaryIconFile, fileURL.lastPathComponent.contains(primaryIconFile) {
                return true
            } else if iconInfo.iconFiles.contains(where: { iconName in
                fileURL.lastPathComponent.range(of: iconName) != nil
            }){
                return true
            }
            
            return false
        })
    }
    
    private func findDatabaseFiles(in folder: URL) -> [URL] {
        var files = [URL]()
        
        if let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys:nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.isSQLiteURL() {
                    files.append(fileURL)
                }
            }
        }
        
        return files
    }
    
    private func readPlist(from plistURL: URL) -> [String: Any]? {
        guard let plistData = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData,
                  options: [],
                  format: nil
              ) as? [String: Any] else {
            print("Failed to read plist")
            return nil
        }
        return plist
    }
    
    private func extractAppIconsInfo(from plist: [String: Any]) -> IconInfo? {
        // Different keys to check for app icons
        let iconKeys = [
            "CFBundleIcons",
            "CFBundleIconFiles",
            "XSAppIconAssets"
        ]
        
        var iconFiles: [String] = []
        
        // Check each potential icon key
        for key in iconKeys {
            if let icons = plist[key] as? [String] {
                iconFiles.append(contentsOf: icons)
            } else if let iconDict = plist[key] as? [String: Any] {
                // Handle nested dictionary case
                if let primaryIcons = iconDict["CFBundlePrimaryIcon"] as? [String: Any],
                   let icons = primaryIcons["CFBundleIconFiles"] as? [String] {
                    iconFiles.append(contentsOf: icons)
                }
            }
        }
        
        // Try to find the primary icon
        let primaryIconFile = iconFiles.first
        
        return IconInfo(
            iconFiles: iconFiles,
            primaryIconFile: primaryIconFile
        )
    }
    
    private func loadIcons(from iconURL: [URL]) -> NSImage? {
        if let iconURL = iconURL.first, let image = NSImage(contentsOf: iconURL) {
            let ratio = image.size.height / image.size.width
            image.size.height = 20
            image.size.width = 20 / ratio
            return image.withRoundedCorners(cornerRadius: 5)
        }
        
        return nil
    }
}
