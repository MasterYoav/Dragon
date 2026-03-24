//
//  DragonTests.swift
//  DragonTests
//
//  Created by Yoav Peretz on 24/03/2026.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Dragon

struct DragonTests {
    @MainActor @Test func audioFormatsStayAudioOnly() async throws {
        let formats = DragonConversionCatalog.availableFormats(forFileExtension: "mp3")

        #expect(formats.isEmpty == false)
        #expect(formats.allSatisfy { $0.category == .audio })
        #expect(formats.contains(.mp3) == false)
        #expect(formats.contains(.m4a))
        #expect(formats.contains(.aac))
    }

    @MainActor @Test func imageFormatsStayImageOnly() async throws {
        let formats = DragonConversionCatalog.availableFormats(forFileExtension: "png")
        let webPSupported = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []).contains(UTType.webP.identifier)

        #expect(formats.isEmpty == false)
        #expect(formats.allSatisfy { $0.category == .image })
        #expect(formats.contains(.png) == false)
        #expect(formats.contains(.webP) == webPSupported)
    }

    @MainActor @Test func powerPointFormatsStayDocumentScoped() async throws {
        let formats = DragonConversionCatalog.availableFormats(forFileExtension: "pptx")

        #expect(formats.contains(.pdf))
        #expect(formats.contains(.markdown))
        #expect(formats.contains(.docx) == false)
        #expect(formats.contains(.odt) == false)
        #expect(formats.allSatisfy { $0.category == .document })
    }

    @MainActor @Test func builtInToolsResolveWithoutBundledDependencies() async throws {
        let textutilURL = try DragonBundledTool.textutil.resolvedExecutableURL()
        let dittoURL = try DragonBundledTool.ditto.resolvedExecutableURL()
        let unzipURL = try DragonBundledTool.unzip.resolvedExecutableURL()

        #expect(textutilURL.path.hasSuffix("/textutil"))
        #expect(dittoURL.path.hasSuffix("/ditto"))
        #expect(unzipURL.path.hasSuffix("/unzip"))
    }
}
