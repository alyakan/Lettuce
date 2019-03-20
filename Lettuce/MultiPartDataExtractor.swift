//
//  MultiPartDataExtractor.swift
//  UnitTests
//
//  Created by Yousef Hamza on 1/13/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class MutliPartPiece {
    let name: String
    let fileName: String?
    let contentType: String?
    let data: Data

    init(name: String, fileName: String?, contentType: String?, data: Data) {
        self.name = name
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
    }

    var valueString: String? {
        return String(data: data, encoding: .utf8)
    }

    var valueImage: UIImage? {
        return UIImage(data: data)
    }
}

extension Data {
    var attachmentFromMultiPart: [MutliPartPiece]? {
        let boundaryString = "---------------------------14737809831466499882746641449";
        let boundary = String(format: "\r\n--%@\r\n", boundaryString).data(using: .utf8)!
        let endBoundary = String(format: "\r\n--%@--\r\n", boundaryString).data(using: .utf8)!
        let sperator = "\r\n\r\n".data(using: .utf8)!

        guard var startBoundaryRange = range(of: boundary, options: [], in: startIndex..<endIndex) else {
            return nil
        }
        var endBoundaryRange = range(of: boundary, options: [], in: 0..<count)

        var pieces: [MutliPartPiece] = []
        while true {
            endBoundaryRange = range(of: boundary, options: [], in: startBoundaryRange.upperBound..<endIndex)
            if endBoundaryRange == nil {
                endBoundaryRange = range(of: endBoundary, options: [], in: startBoundaryRange.upperBound..<endIndex)
            }
            if endBoundaryRange == nil {
                break
            }

            let dataSeperatorRange = range(of: sperator,
                                           options: [],
                                           in: startBoundaryRange.upperBound..<endBoundaryRange!.lowerBound)
            let sectionData = subdata(in: dataSeperatorRange!.upperBound..<endBoundaryRange!.lowerBound)

            let descriptionData = subdata(in: startBoundaryRange.upperBound..<dataSeperatorRange!.lowerBound)
            let sectionHeader = String(data: descriptionData, encoding: .utf8)!
            let (name, fileName, contentType) = self.sectionData(from: sectionHeader)

            let multiPartPiece = MutliPartPiece(name: name, fileName: fileName, contentType: contentType, data: sectionData)
            pieces.append(multiPartPiece)

            guard let newStartBoundary = range(of: boundary, options: [], in: endBoundaryRange!.upperBound..<endIndex) else {
                break
            }
            startBoundaryRange = newStartBoundary
        }
        return pieces
    }

    private func sectionData(from description: String) -> (String, String?, String?) {
        var name: String!
        var fileName: String? = nil
        var contentType: String? = nil

        /*
         * Explaining the regex
         * ====================
         * (...) are what's called a capturing group, each one will crossespond to a range in the result returned.
         * There's 13 capturing group in this regex, the capturing groups followed by a `*` is optional
         *
         * ^(.*): (.*); ((.*)=\"(.*)\")($|;)( (.*)=\"(.*)\")*[;|\r\n]*((.*): (.*))*
         *  ^     ^     ^^      ^      ^    ^ ^      ^                ^^     ^
         *
         * Example:
         * "Content-Disposition: form-data; name="application_token"; file="asdasd"
         *  Content-Type: asda"
         *
         * GROUP 1: Content-Dispoistion
         * GROUP 2: form-data
         * GROUP 3: Content-Dispoistion
         * GROUP 4: name="application_token"
         * GROUP 5: name
         * GROUP 6: application_token
         * GROUP 7: ;
         * GROUP 8:  file="asdasd"
         * GROUP 9: file
         * GROUP 10: asdasd
         * GROUP 11: Content-Type: asda
         * GROUP 12: Content-Type
         * GROUP 13: asda
         *
         * Another Example:
         * "Content-Disposition: form-data; name="application_token";"
         *
         * GROUP 1: Content-Dispoistion
         * GROUP 2: form-data
         * GROUP 3: Content-Dispoistion
         * GROUP 4: name="application_token"
         * GROUP 5: name
         * GROUP 6: application_token
         * GROUP 7: $
         * GROUP 8-13: EMPTY
         *
         */
        let regex = try! NSRegularExpression(pattern: "^(.*): (.*); ((.*)=\"(.*)\")($|;)( (.*)=\"(.*)\")*[;|\r\n]*((.*): (.*))*",
                                             options: [])
        let ranges = regex.matches(in: description.replacingOccurrences(of: "\r", with: ""),
                                   options: [],
                                   range: NSRange(location: 0, length: description.count))
        guard let result = ranges.first, result.numberOfRanges == 13 else {
            return ("", nil, nil)
        }

        let nameRange = result.range(at: 5)
        name = String(description[Range(nameRange, in: description)!])

        let fileNameRange = result.range(at: 9)
        if (fileNameRange.location != NSNotFound) {
            fileName = String(description[Range(fileNameRange, in: description)!])
        }

        let contentTypeRange = result.range(at: 12)
        if (contentTypeRange.location != NSNotFound) {
            contentType = String(description[Range(contentTypeRange, in: description)!]) +
                          String(description[description.index(before: description.endIndex)])
        }

        return (name, fileName, contentType)
    }
}
