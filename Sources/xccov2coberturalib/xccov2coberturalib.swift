import Foundation
import Darwin

/** Useful links
 * https://github.com/SonarSource/sonar-scanning-examples/blob/master/swift-coverage/swift-coverage-example/xccov-to-sonarqube-generic.sh
 * https://gist.github.com/csaby02/ab2441715a89865a7e8e29804df23dc6
 * https://www.softvision.com/blog/integrate-xcode-code-coverage-xccov-into-jenkins/
 * https://github.com/nakiostudio/xcov-core/
 */

struct FunctionCoverageReport: Codable {
    let coveredLines: Int
    let executableLines: Int
    let executionCount: Int
    let lineCoverage: Double
    let lineNumber: Int
    let name: String
}

struct FileCoverageReport: Codable {
    let coveredLines: Int
    let executableLines: Int
    let functions: [FunctionCoverageReport]
    let lineCoverage: Double
    let name: String
    let path: String
}

struct TargetCoverageReport: Codable {
    let buildProductPath: String
    let coveredLines: Int
    let executableLines: Int
    let files: [FileCoverageReport]
    let lineCoverage: Double
    let name: String
}

public struct CoverageReport: Codable {
    let executableLines: Int
    let targets: [TargetCoverageReport]
    let lineCoverage: Double
    let coveredLines: Int
}

func parseCoverageReport(at fileURL: URL) throws -> CoverageReport {
    let jsonString = try launchXccov(arguments: ["view", fileURL.path, "--json"])
    guard let data = jsonString.data(using: .utf8) else {
        exit(0)
    }

    return try JSONDecoder().decode(CoverageReport.self, from: data)
}

public struct CoverageArchive {

    typealias FilePath = String
    typealias LineNumber = Int
    typealias Hits = Int

    struct FileReport {
        let filePath: String
        let hitsPerLine: [LineNumber: Hits]
    }

    var coveragePerFile: [FilePath: FileReport]
}

@objc protocol IDECoverageUnarchiver {
    @objc init(archivePath: String) throws
    @objc(getKeys:) func keys() throws -> [String]
    @objc func unarchiveCoverageLines(forKey key: String) throws -> [NSObject]
}

@objc protocol DVTSourceFileLineCoverageData {
    @objc var isExecutable: Bool { get }
    @objc var lineNumber: CUnsignedInt { get }
    @objc var executionCount: CUnsignedLongLong { get }
}


func parseCoverageArchive(at fileURL: URL) throws -> CoverageArchive {
    guard dlopen("/Applications/Xcode.app/Contents/Frameworks/IDEFoundation.framework/Versions/A/IDEFoundation", RTLD_LAZY) != nil else {
        let errorString = String(validatingUTF8: dlerror())
        throw Xccov2CoberturaError.IDEFoundationLoading(message: errorString)
    }

    let coverageUnarchiverClass = unsafeBitCast(NSClassFromString("IDECoverageUnarchiver"), to: IDECoverageUnarchiver.Type.self)
    let unarchiver = try coverageUnarchiverClass.init(archivePath: fileURL.path)

    var coverageArchive = CoverageArchive(coveragePerFile: [:])

    for sourceFilePath in try unarchiver.keys() {
        var hitsPerLine: [CoverageArchive.LineNumber: CoverageArchive.Hits] = [:]
        for coverageDataObject in try unarchiver.unarchiveCoverageLines(forKey: sourceFilePath) {
            guard
                let isExecutable = coverageDataObject.value(forKey: "isExecutable") as? Bool,
                isExecutable,
                let lineNumber = coverageDataObject.value(forKey: "lineNumber") as? Int,
                let executionCount = coverageDataObject.value(forKey: "executionCount") as? Int,
                executionCount > 0 else {
                    continue
            }
            hitsPerLine[lineNumber] = executionCount
        }
        let fileReport = CoverageArchive.FileReport(filePath: sourceFilePath, hitsPerLine: hitsPerLine)
        coverageArchive.coveragePerFile[fileReport.filePath] = fileReport
    }

    return coverageArchive
}


func launchXccov(arguments: [String]) throws -> String {
    let pipe = Pipe()
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = ["xcrun", "xccov"] + arguments
    process.standardOutput = pipe
    process.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw Xccov2CoberturaError.invalidXccovReturnValue(command: arguments.joined(), status: process.terminationStatus)
    }

    guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
        throw Xccov2CoberturaError.invalidXccovOutput(command: arguments.joined())
    }

    return output
}

public struct Options {
    let targetsToExclude: [String]
    let packagesToExclude: [String]

    public init(targetsToExclude: [String] = [], packagesToExclude: [String] = []) {
        self.targetsToExclude = targetsToExclude
        self.packagesToExclude = packagesToExclude
    }
}

extension String {
    func contains(elementOfArray: [String]) -> Bool {
        for element in elementOfArray {
            if self.contains(element) {
                return true
            }
        }

        return false
    }
}

public func generateCoberturaReport(from coverageReport: CoverageReport, coverageArchive: CoverageArchive, sourceRootPath: String, options: Options = Options()) throws -> String {

    let dtd = XMLDTD()
    dtd.name = "coverage"
    dtd.systemID = "http://cobertura.sourceforge.net/xml/coverage-04.dtd"

    let rootElement = XMLElement(name: "coverage")
    rootElement.addAttribute(XMLNode.attribute(withName: "line-rate", stringValue: "\(coverageReport.lineCoverage)") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "branch-rate", stringValue: "1.0") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "lines-covered", stringValue: "\(coverageReport.coveredLines)") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "lines-valid", stringValue: "\(coverageReport.executableLines)") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "timestamp", stringValue: "\(Date().timeIntervalSince1970)") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "version", stringValue: "diff_coverage 0.1") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "complexity", stringValue: "0.0") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "branches-valid", stringValue: "1.0") as! XMLNode)
    rootElement.addAttribute(XMLNode.attribute(withName: "branches-covered", stringValue: "1.0") as! XMLNode)

    let doc = XMLDocument(rootElement: rootElement)
    doc.version = "1.0"
    doc.dtd = dtd
    doc.documentContentKind = .xml

    let sourceElement = XMLElement(name: "sources")
    rootElement.addChild(sourceElement)
    sourceElement.addChild(XMLElement(name: "source", stringValue: sourceRootPath))

    let packagesElement = XMLElement(name: "packages")
    rootElement.addChild(packagesElement)

    var allFiles = [FileCoverageReport]()
    for targetCoverageReport in coverageReport.targets {
        // Filter out targets
        if targetCoverageReport.name.contains(elementOfArray: options.targetsToExclude) {
            continue
        }

        // Filter out files by package
        let targetFiles = targetCoverageReport.files.filter { !$0.path.contains(elementOfArray: options.packagesToExclude) }
        allFiles.append(contentsOf: targetFiles)
    }

    // Sort files to avoid duplicated packages
    allFiles = allFiles.sorted(by: { $0.path > $1.path })

    var currentPackage = ""
    var currentPackageElement: XMLElement!
    var isNewPackage = false

    for fileCoverageReport in allFiles {
        // Define file path relative to source!
        let filePath = fileCoverageReport.path.replacingOccurrences(of: sourceRootPath + "/", with: "")
        let pathComponents = filePath.split(separator: "/")
        let packageName = pathComponents[0..<pathComponents.count - 1].joined(separator: ".")
        let fileReport = coverageArchive.coveragePerFile[fileCoverageReport.path]

        isNewPackage = currentPackage != packageName

        if isNewPackage {
            currentPackageElement = XMLElement(name: "package")
            packagesElement.addChild(currentPackageElement)
        }

        currentPackage = packageName
        if isNewPackage {
            currentPackageElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: packageName) as! XMLNode)
            currentPackageElement.addAttribute(XMLNode.attribute(withName: "line-rate", stringValue: "\(fileCoverageReport.lineCoverage)") as! XMLNode)
            currentPackageElement.addAttribute(XMLNode.attribute(withName: "branch-rate", stringValue: "1.0") as! XMLNode)
            currentPackageElement.addAttribute(XMLNode.attribute(withName: "complexity", stringValue: "0.0") as! XMLNode)
        }

        let classElement = XMLElement(name: "class")
        classElement.addAttribute(XMLNode.attribute(withName: "name", stringValue: "\(packageName).\((fileCoverageReport.name as NSString).deletingPathExtension)") as! XMLNode)
        classElement.addAttribute(XMLNode.attribute(withName: "filename", stringValue: "\(filePath)") as! XMLNode)
        classElement.addAttribute(XMLNode.attribute(withName: "line-rate", stringValue: "\(fileCoverageReport.lineCoverage)") as! XMLNode)
        classElement.addAttribute(XMLNode.attribute(withName: "branch-rate", stringValue: "1.0") as! XMLNode)
        classElement.addAttribute(XMLNode.attribute(withName: "complexity", stringValue: "0.0") as! XMLNode)
        currentPackageElement.addChild(classElement)

        let linesElement = XMLElement(name: "lines")
        classElement.addChild(linesElement)

        for functionCoverageReport in fileCoverageReport.functions {
            for index in 0..<functionCoverageReport.executableLines {
                let lineNumber = functionCoverageReport.lineNumber + index
                guard let lineHits = fileReport?.hitsPerLine[lineNumber] else {
                    continue
                }
                let lineElement = XMLElement(kind: .element, options: .nodeCompactEmptyElement)
                lineElement.name = "line"
                lineElement.addAttribute(XMLNode.attribute(withName: "number", stringValue: "\(lineNumber)") as! XMLNode)
                lineElement.addAttribute(XMLNode.attribute(withName: "branch", stringValue: "false") as! XMLNode)
                lineElement.addAttribute(XMLNode.attribute(withName: "hits", stringValue: "\(lineHits)") as! XMLNode)
                linesElement.addChild(lineElement)
            }
        }
    }

    return doc.xmlString(options: [.nodePrettyPrint])
}

struct ResultBundle: Codable {
    let creatingWorkspaceFilePath: String
    let actions: [ResultBundleAction]

    enum CodingKeys: String, CodingKey {
        case creatingWorkspaceFilePath = "CreatingWorkspaceFilePath"
        case actions = "Actions"
    }
}

struct ResultBundleAction: Codable {
    let schemeCommand: String
    let actionResult: ResultBundleActionResult

    enum CodingKeys: String, CodingKey {
        case schemeCommand = "SchemeCommand"
        case actionResult = "ActionResult"
    }
}

struct ResultBundleActionResult: Codable {
    let codeCoverageArchivePath: String
    let codeCoveragePath: String
    let hasCodeCoverage: Bool

    enum CodingKeys: String, CodingKey {
        case codeCoverageArchivePath = "CodeCoverageArchivePath"
        case codeCoveragePath = "CodeCoveragePath"
        case hasCodeCoverage = "HasCodeCoverage"
    }
}

public enum Xccov2CoberturaError: Error {
    case invalidResultBundle(message: String)
    case IDEFoundationLoading(message: String?)
    case invalidXccovReturnValue(command: String, status: Int32)
    case invalidXccovOutput(command: String)
}

public func generateCoberturaReport(fromResultBundleAt fileURL: URL) throws -> String {
    guard
        let bundle = Bundle(url: fileURL),
        let bundleDictionary = bundle.infoDictionary,
        let version = bundleDictionary["FormatVersion"] as? String, version == "1.2" else {
        throw Xccov2CoberturaError.invalidResultBundle(message: "Incompatible result bundle at \(fileURL.path)")
    }

    let data = try PropertyListSerialization.data(fromPropertyList: bundleDictionary, format: .binary, options: 0)
    let resultBundle = try PropertyListDecoder().decode(ResultBundle.self, from: data)

    guard resultBundle.actions.count == 1, resultBundle.actions[0].schemeCommand == "Test" else {
        throw Xccov2CoberturaError.invalidResultBundle(message: "Result bundles with more than one test actions are not supported")
    }

    let actionResult = resultBundle.actions[0].actionResult
    guard actionResult.hasCodeCoverage else {
        throw Xccov2CoberturaError.invalidResultBundle(message: "Result bundles doesn't have coverage metrics")
    }

    let reportFileURL = fileURL.appendingPathComponent(actionResult.codeCoveragePath)
    let archiveFileURL = fileURL.appendingPathComponent(actionResult.codeCoverageArchivePath)
    let sourceRootFileURL = URL(fileURLWithPath: resultBundle.creatingWorkspaceFilePath).deletingLastPathComponent()
    let coverageReport = try parseCoverageReport(at: reportFileURL)
    let coverageArchive = try parseCoverageArchive(at: archiveFileURL)
    let report = try generateCoberturaReport(from: coverageReport, coverageArchive: coverageArchive, sourceRootPath: sourceRootFileURL.path)

    return report
}
