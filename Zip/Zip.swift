//
//  Zip.swift
//  Zip
//
//  Created by Roy Marmelstein on 13/12/2015.
//  Copyright © 2015 Roy Marmelstein. All rights reserved.
//

import Foundation
import minizip

/// Zip error type
public enum ZipError: ErrorProtocol {
    /// File not found
    case fileNotFound
    /// Unzip fail
    case unzipFail
    /// Zip fail
    case zipFail

    /// User readable description
    public var description: String {
        switch self {
        case .fileNotFound: return NSLocalizedString("File not found.", comment: "")
        case .unzipFail: return NSLocalizedString("Failed to unzip file.", comment: "")
        case .zipFail: return NSLocalizedString("Failed to zip file.", comment: "")
        }
    }
}

/// Zip class
public class Zip {
    
    // MARK: Lifecycle
    
    /**
     Init
     
     - returns: Zip object
     */
    public init () {
    }
    
    // MARK: Unzip
        
    /**
     Unzip file
     
     - parameter zipFilePath: Local file path of zipped file. NSURL.
     - parameter destination: Local file path to unzip to. NSURL.
     - parameter overwrite:   Overwrite bool.
     - parameter password:    Optional password if file is protected.
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.

     - throws: Error if unzipping fails or if fail is not found. Can be printed with a description variable.
     */

    public class func unzipFile(_ zipFilePath: URL, destination: URL, overwrite: Bool, password: String?, progress: ((progress: Double) -> ())?) throws {
        
        // File manager
        let fileManager = FileManager.default()

        // Check whether a zip file exists at path.
        guard let path = zipFilePath.path, let destinationPath = destination.path else {
            throw ZipError.fileNotFound
        }
        if fileManager.fileExists(atPath: path) == false || zipFilePath.pathExtension != "zip" {
            throw ZipError.fileNotFound
        }
        
        // Unzip set up
        var ret: Int32 = 0
        var crc_ret: Int32 = 0
        let bufferSize: UInt32 = 4096
        var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(bufferSize))
        
        // Progress handler set up
        var totalSize: Double = 0.0
        var currentPosition: Double = 0.0
        let fileAttributes = try fileManager.attributesOfItem(atPath: path)
        if let attributeFileSize = fileAttributes[FileAttributeKey.size.rawValue] as? Double {
            totalSize += attributeFileSize
        }

        // Begin unzipping
        let zip = unzOpen64(path)
        if unzGoToFirstFile(zip) != UNZ_OK {
            throw ZipError.unzipFail
        }
        repeat {
            if let cPassword = password?.cString(using: String.Encoding.ascii) {
                ret = unzOpenCurrentFilePassword(zip, cPassword)
            }
            else {
                ret = unzOpenCurrentFile(zip);
            }
            if ret != UNZ_OK {
                throw ZipError.unzipFail
            }
            var fileInfo = unz_file_info64()
            memset(&fileInfo, 0, sizeof(unz_file_info))
            ret = unzGetCurrentFileInfo64(zip, &fileInfo, nil, 0, nil, 0, nil, 0)
            if ret != UNZ_OK {
                unzCloseCurrentFile(zip)
                throw ZipError.unzipFail
            }
            currentPosition += Double(fileInfo.compressed_size)
            let fileNameSize = Int(fileInfo.size_filename) + 1
            let fileName = UnsafeMutablePointer<CChar>(allocatingCapacity: fileNameSize)
            unzGetCurrentFileInfo64(zip, &fileInfo, fileName, UInt(fileNameSize), nil, 0, nil, 0)
            fileName[Int(fileInfo.size_filename)] = 0
            let ps = String(cString: fileName, encoding: String.Encoding.utf8)
            var isDirectory = false
            let fileInfoSizeFileName = Int(fileInfo.size_filename-1)
            if (fileName[fileInfoSizeFileName] == "/".cString(using: String.Encoding.utf8)?.first || fileName[fileInfoSizeFileName] == "\\".cString(using: String.Encoding.utf8)?.first) {
                isDirectory = true;
            }
            free(fileName)
            if var pathString = ps {
                if pathString.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) != nil {
                    pathString = pathString.replacingOccurrences(of: "\\", with: "/")
                }
                guard let fullPath = try! destination.appendingPathComponent(pathString).path else {
                    throw ZipError.unzipFail
                }
                let creationDate = Date()
                let directoryAttributes: [String: AnyObject] = [FileAttributeKey.creationDate.rawValue: creationDate, FileAttributeKey.modificationDate.rawValue: creationDate]
                do {
                    if isDirectory {
                        try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: directoryAttributes)
                    }
                    else {
                        try fileManager.createDirectory(atPath: destinationPath, withIntermediateDirectories: true, attributes: directoryAttributes)
                    }
                } catch {}
                if fileManager.fileExists(atPath: fullPath) && !isDirectory && !overwrite {
                    unzCloseCurrentFile(zip)
                    ret = unzGoToNextFile(zip)
                }
                var filePointer: UnsafeMutablePointer<FILE>?
                filePointer = fopen(fullPath, "wb")
                while filePointer != nil {
                    let readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                    if readBytes > 0 {
                        fwrite(buffer, Int(readBytes), 1, filePointer)
                    }
                    else {
                        break
                    }
                }
                fclose(filePointer)
                crc_ret = unzCloseCurrentFile(zip)
                if crc_ret == UNZ_CRCERROR {
                    throw ZipError.unzipFail
                }
                ret = unzGoToNextFile(zip)
                
                // Update progress handler
                if let progressHandler = progress{
                    progressHandler(progress: (currentPosition/totalSize))
                }
            }
            
        } while (ret == UNZ_OK && ret != UNZ_END_OF_LIST_OF_FILE)
        
        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(progress: 1.0)
        }

    }
    
    // MARK: Zip
    
    /**
    Zip files.
    
    - parameter paths:       Array of NSURL filepaths.
    - parameter zipFilePath: Destination NSURL, should lead to a .zip filepath.
    - parameter password:    Password string. Optional.
    - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.

    - throws: Error if zipping fails.
    */
    public class func zipFiles(_ paths: [URL], zipFilePath: URL, password: String?, progress: ((progress: Double) -> ())?) throws {
        
        // File manager
        let fileManager = FileManager.default()
        
        // Check whether a zip file exists at path.
        guard let destinationPath = zipFilePath.path else {
            throw ZipError.fileNotFound
        }
        
        // Process zip paths
        let processedPaths = ZipUtilities().processZipPaths(paths)
        
        // Zip set up
        let chunkSize: Int = 16384
        
        // Progress handler set up
        var currentPosition: Double = 0.0
        var totalSize: Double = 0.0
        // Get totalSize for progress handler
        for path in processedPaths {
            do {
                let filePath = path.filePath()
                let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)
                let fileSize = fileAttributes[FileAttributeKey.size.rawValue] as? Double
                if let fileSize = fileSize {
                    totalSize += fileSize
                }
            }
            catch {}
        }
        
        // Begin Zipping
        let zip = zipOpen(destinationPath, APPEND_STATUS_CREATE)
        for path in processedPaths {
            let filePath = path.filePath()
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
            if !isDirectory {
                let input = fopen(filePath, "r")
                if input == nil {
                    throw ZipError.zipFail
                }
                let fileName = path.fileName
                var zipInfo: zip_fileinfo = zip_fileinfo(tmz_date: tm_zip(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0), dosDate: 0, internal_fa: 0, external_fa: 0)
                do {
                    let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)
                    if let fileDate = fileAttributes[FileAttributeKey.modificationDate.rawValue] as? Date {
                        let components = Calendar.current().components([.year, .month, .day, .hour, .minute, .second], from: fileDate)
                        zipInfo.tmz_date.tm_sec = UInt32(components.second!)
                        zipInfo.tmz_date.tm_min = UInt32(components.minute!)
                        zipInfo.tmz_date.tm_hour = UInt32(components.hour!)
                        zipInfo.tmz_date.tm_mday = UInt32(components.day!)
                        zipInfo.tmz_date.tm_mon = UInt32(components.month!) - 1
                        zipInfo.tmz_date.tm_year = UInt32(components.year!)
                    }
                    if let fileSize = fileAttributes[FileAttributeKey.size.rawValue] as? Double {
                        currentPosition += fileSize
                    }
                }
                catch {}
                let buffer = malloc(chunkSize)
                if let password = password, let fileName = fileName {
                    zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil,Z_DEFLATED, Z_DEFAULT_COMPRESSION, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, password, 0)
                }
                else if let fileName = fileName {
                    zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil,Z_DEFLATED, Z_DEFAULT_COMPRESSION, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, nil, 0)
                }
                else {
                    throw ZipError.zipFail
                }
                var length: Int = 0
                while (feof(input) == 0) {
                    length = fread(buffer, 1, chunkSize, input)
                    zipWriteInFileInZip(zip, buffer, UInt32(length))
                }
                
                // Update progress handler
                if let progressHandler = progress{
                    progressHandler(progress: (currentPosition/totalSize))
                }
                
                zipCloseFileInZip(zip)
                free(buffer)
                fclose(input)
            }
        }
        zipClose(zip, nil)
        
        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(progress: 1.0)
        }
    }
    
    

}
