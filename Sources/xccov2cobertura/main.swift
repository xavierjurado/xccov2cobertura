import Foundation
import xccov2coberturalib
import Commandant

let resultBundleURL = URL(fileURLWithPath: "/Users/xavi/Library/Developer/Xcode/DerivedData/HackerRank-coaqzeudeydlszedjdedtynottjd/Logs/Test/Test-HackerRank-2019.03.22_22-08-29-+0100.xcresult")
let resultBundle2URL = URL(fileURLWithPath: "/Users/xavi/Library/Developer/Xcode/DerivedData/HackerRank-coaqzeudeydlszedjdedtynottjd/Logs/Test/Test-HackerRank-2019.03.24_02-57-04-+0100.xcresult")
let resultBundle3URL = URL(fileURLWithPath: "/Users/xavi/Library/Developer/Xcode/DerivedData/fotocasa-amuxxgtxavpjzgfjnwqajnsbbvzc/Logs/Test/Test-fotocasa-2019.03.24_13-45-18-+0100.xcresult")

let report = try generateCoberturaReport(fromResultBundleAt: resultBundle3URL)
