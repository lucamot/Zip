//
//  QuickZip.swift
//  Zip
//
//  Created by Roy Marmelstein on 16/01/2016.
//  Copyright © 2016 Roy Marmelstein. All rights reserved.
//

import Foundation

extension Zip {
    
    //MARK: Quick Unzip

    /**
     Quick unzip a file. Unzips to a new folder inside the app's documents folder with the zip file's name.
     
     - parameter path: Path of zipped file. NSURL.
     
     - throws: Error if unzipping fails or if file is not found. Can be printed with a description variable.
     
     - returns: NSURL of the destination folder.
     */
    public class func quickUnzipFile(_ path: URL, intermediateDirPath: String = "", destination: FileManager.SearchPathDirectory = .cachesDirectory) throws -> URL {
        return try quickUnzipFile(path, intermediateDirPath: intermediateDirPath, destination: destination, progress: nil)
    }
    
    /**
     Quick unzip a file. Unzips to a new folder inside the app's documents folder with the zip file's name.
     
     - parameter path: Path of zipped file. NSURL.
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.
     
     - throws: Error if unzipping fails or if file is not found. Can be printed with a description variable.
     
     - returns: NSURL of the destination folder.
     */
    public class func quickUnzipFile(_ path: URL, intermediateDirPath: String = "", destination: FileManager.SearchPathDirectory = .cachesDirectory, progress: ((progress: Double) -> ())?) throws -> URL {
        let fileManager = FileManager.default()
        guard let fileExtension = path.pathExtension, let fileName = path.lastPathComponent else {
            throw ZipError.unzipFail
        }
        let directoryName = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        var documentsUrl = fileManager.urlsForDirectory(destination, inDomains: .userDomainMask)[0] as URL
        if intermediateDirPath.characters.count > 0 {
            documentsUrl = try! documentsUrl.appendingPathComponent(intermediateDirPath)
        }
        let destinationUrl = try! documentsUrl.appendingPathComponent(directoryName, isDirectory: true)
        try self.unzipFile(path, destination: destinationUrl, overwrite: true, password: nil, progress: progress)
        return destinationUrl
    }
    
    //MARK: Quick Zip
    
    /**
    Quick zip files.
    
    - parameter paths: Array of NSURL filepaths.
    - parameter fileName: File name for the resulting zip file.
    
    - throws: Error if zipping fails.
    
    - returns: NSURL of the destination folder.
    */
    public class func quickZipFiles(_ paths: [URL], fileName: String, destination: FileManager.SearchPathDirectory = .cachesDirectory) throws -> URL {
        return try quickZipFiles(paths, fileName: fileName, destination: destination, progress: nil)
    }

    /**
    Quick zip files.
    
    - parameter paths: Array of NSURL filepaths.
    - parameter fileName: File name for the resulting zip file.
    - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.

    - throws: Error if zipping fails.
    
    - returns: NSURL of the destination folder.
    */
    public class func quickZipFiles(_ paths: [URL], fileName: String, destination: FileManager.SearchPathDirectory = .cachesDirectory, progress: ((progress: Double) -> ())?) throws -> URL {
        let fileManager = FileManager.default()
        let documentsUrl = fileManager.urlsForDirectory(destination, inDomains: .userDomainMask)[0] as URL
        let destinationUrl = try! documentsUrl.appendingPathComponent("\(fileName).zip")
        try self.zipFiles(paths, zipFilePath: destinationUrl, password: nil, progress: progress)
        return destinationUrl
    }
    

}
