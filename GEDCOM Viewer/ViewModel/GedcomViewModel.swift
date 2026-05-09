//
//  GedcomViewModel.swift
//  GEDCOM Viewer
//
//  Created by Codex on 13/10/2025.
//

import Combine
import Foundation

@MainActor
final class GedcomViewModel: ObservableObject {
    @Published private(set) var state = GedcomUIState()

    private let parser = GedcomParser()
    private let processingQueue = DispatchQueue(label: "com.lewisdeveloping.gedcomviewer.parser")
    private let defaults = UserDefaults.standard
    // Operation queue used for NSFileCoordinator coordination blocks
    private let fileCoordinationQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.lewisdeveloping.gedcomviewer.filecoordination"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private var cachedData: GedcomData?
    private var currentSource: DocumentSource?

    private func updateState(_ transform: (inout GedcomUIState) -> Void) {
        var newState = state
        transform(&newState)
        state = newState
    }

    init() {
        loadSavedSource()
    }

    func loadSample() {
        let previousState = state
        let previousSource = currentSource
        let previousCachedData = cachedData

        updateState { state in
            state.isLoading = true
            state.needsFileSelection = false
            state.currentFileName = Sample.fileName
            state.isSampleData = true
            state.selectedIndividualId = nil
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try sampleURL()
                let data = try Data(contentsOf: url)
                let parsed = try await parse(data: data, sourceIdentifier: Sample.sourceIdentifier)
                cachedData = parsed
                currentSource = .sample
                save(mode: .sample, bookmark: nil, fileName: Sample.fileName)
                updateState { state in
                    state.data = parsed
                    state.error = nil
                    state.needsFileSelection = false
                    state.currentFileName = Sample.fileName
                    state.isSampleData = true
                    state.lastSuccessfulLoadID = UUID()
                    state.selectedIndividualId = nil
                }
                finishLoading()
            } catch {
                if previousState.data == nil {
                    clearSavedSource()
                }
                cachedData = previousCachedData
                currentSource = previousSource
                updateState { state in
                    var restored = previousState
                    restored.isLoading = false
                    let fallback = String(
                        localized: "error.sample.load_failed",
                        defaultValue: "Unable to load sample data.",
                        bundle: .main
                    )
                    restored.error = error.localizedDescription.nilIfBlank ?? fallback
                    state = restored
                }
            }
        }
    }

    func load(url: URL) {
        let previousState = state
        let previousSource = currentSource
        let previousCachedData = cachedData

        guard isSupportedGedcomFile(url) else {
            updateState { state in
                var restored = previousState
                restored.isLoading = false
                restored.error = Unsupported.fileTypeMessage
                state = restored
            }
            cachedData = previousCachedData
            currentSource = previousSource
            return
        }

        let provisionalName = url.lastPathComponent
        updateState { state in
            state.isLoading = true
            state.needsFileSelection = false
            state.currentFileName = provisionalName
            state.isSampleData = false
            state.selectedIndividualId = nil
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let shouldStop = url.startAccessingSecurityScopedResource()
                defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }

                let displayName = self.displayName(for: url)
                let sourceIdentifier = self.makeSourceIdentifier(for: url)

                // First attempt: direct read
                let data: Data
                do {
                    data = try tryReadData(at: url)
                } catch {
                    // Retry using coordinated read for file providers like Google Drive
                    data = try coordinatedRead(at: url)
                }

                let bookmarkOptions: URL.BookmarkCreationOptions
#if os(macOS) || targetEnvironment(macCatalyst)
                bookmarkOptions = [.withSecurityScope]
#else
                bookmarkOptions = []
#endif
                let bookmark: Data?
                do {
                    bookmark = try url.bookmarkData(
                        options: bookmarkOptions,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } catch {
                    // Some providers refuse bookmark creation; keep loading without persistence.
                    // This is common with certain third‑party file providers.
                    bookmark = nil
                }

                let parsed = try await self.parse(data: data, sourceIdentifier: sourceIdentifier)
                cachedData = parsed
                if let bookmark {
                    currentSource = .file(bookmarkData: bookmark, fileName: displayName)
                    save(mode: .file, bookmark: bookmark, fileName: displayName)
                } else {
                    currentSource = nil
                    clearSavedSource()
                }
                updateState { state in
                    state.data = parsed
                    state.error = nil
                    state.needsFileSelection = false
                    state.currentFileName = displayName
                    state.isSampleData = false
                    state.lastSuccessfulLoadID = UUID()
                    state.selectedIndividualId = nil
                }
                finishLoading()
            } catch {
                if previousState.data == nil {
                    clearSavedSource()
                }
                cachedData = previousCachedData
                currentSource = previousSource
                updateState { state in
                    var restored = previousState
                    restored.isLoading = false
                    restored.error = self.bestUserMessage(for: error)
                    state = restored
                }
            }
        }
    }

    func refresh() {
        let previousState = state
        let previousCachedData = cachedData
        let previousSource = currentSource

        guard let source = currentSource else {
            updateState { state in
                var restored = previousState
                restored.isLoading = false
                if restored.error == nil {
                    restored.error = GedcomError.unableToAccessFile.localizedDescription
                }
                state = restored
            }
            cachedData = previousCachedData
            currentSource = previousSource
            return
        }
        switch source {
        case .sample:
            loadSample()
        case .file(let bookmark, let fileName):
            Task { [weak self] in
                guard let self else { return }
                do {
                    guard let url = try resolveBookmark(bookmark, repairingIfStale: true) else {
                        throw GedcomError.unableToAccessFile
                    }
                    let parsed = try await loadFromSecurityScopedURL(url)
                    cachedData = parsed
                    currentSource = .file(bookmarkData: bookmark, fileName: fileName)
                    updateState { state in
                        state.data = parsed
                        state.error = nil
                        state.needsFileSelection = false
                        state.currentFileName = fileName
                        state.isSampleData = false
                        state.lastSuccessfulLoadID = UUID()
                    }
                    finishLoading()
                } catch {
                    cachedData = previousCachedData
                    currentSource = previousSource
                    updateState { state in
                        var restored = previousState
                        restored.isLoading = false
                        restored.error = self.bestUserMessage(for: error)
                        state = restored
                    }
                }
            }
        }
    }

    func showHome() {
        updateState { state in
            state.isLoading = false
            state.error = nil
            state.needsFileSelection = true
            state.selectedIndividualId = nil
        }
    }

    func openSavedIndex() -> Bool {
        if let cachedData {
            updateState { state in
                state.isLoading = false
                state.data = cachedData
                state.error = nil
                state.needsFileSelection = false
                state.isSampleData = currentSource?.isSample ?? false
            }
            return true
        }
        loadSavedSource()
        return cachedData != nil
    }

    func clearError() {
        updateState { state in
            state.error = nil
        }
    }

    func clearSelection() {
        cachedData = nil
        currentSource = nil
        state = GedcomUIState()
        clearSavedSource()
    }

    func selectIndividual(_ id: String?) {
        updateState { state in
            state.selectedIndividualId = id
        }
    }

    private func loadSavedSource() {
        guard let modeString = defaults.string(forKey: Keys.lastMode),
              let mode = SavedMode(rawValue: modeString) else {
            cachedData = nil
            currentSource = nil
            updateState { state in
                state.isLoading = false
                state.needsFileSelection = true
                state.data = nil
            }
            return
        }

        switch mode {
        case .sample:
            loadSample()
        case .file:
            guard let bookmark = defaults.data(forKey: Keys.lastBookmark),
                  let fileName = defaults.string(forKey: Keys.lastFileName) else {
                cachedData = nil
                currentSource = nil
                updateState { state in
                    state.isLoading = false
                    state.needsFileSelection = true
                    state.data = nil
                }
                return
            }
            updateState { state in
                state.isLoading = true
                state.needsFileSelection = false
                state.currentFileName = fileName
                state.isSampleData = false
                state.selectedIndividualId = nil
                state.lastSuccessfulLoadID = nil
            }
            Task { [weak self] in
                guard let self else { return }
                do {
                    guard let url = try resolveBookmark(bookmark, repairingIfStale: true) else {
                        throw GedcomError.unableToAccessFile
                    }
                    let parsed = try await loadFromSecurityScopedURL(url)
                    cachedData = parsed
                    currentSource = .file(bookmarkData: bookmark, fileName: fileName)
                    updateState { state in
                        state.data = parsed
                        state.error = nil
                        state.needsFileSelection = false
                        state.currentFileName = fileName
                        state.isSampleData = false
                        state.lastSuccessfulLoadID = UUID()
                    }
                    finishLoading()
                } catch {
                    clearSavedSource()
                    cachedData = nil
                    currentSource = nil
                    updateState { state in
                        state.isLoading = false
                        state.error = self.bestUserMessage(for: error)
                        state.needsFileSelection = true
                        state.currentFileName = nil
                        state.isSampleData = false
                        state.selectedIndividualId = nil
                        state.lastSuccessfulLoadID = nil
                        state.data = nil
                    }
                }
            }
        }
    }

    private func finishLoading() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
            self?.updateState { state in
                state.isLoading = false
            }
        }
    }

    private func parse(data: Data, sourceIdentifier: String? = nil) async throws -> GedcomData {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let parsed = try self.parser.parse(data: data, sourceIdentifier: sourceIdentifier)
                    continuation.resume(returning: parsed)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func sampleURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: Sample.resourceName, withExtension: Sample.extension) else {
            throw GedcomError.sampleMissing
        }
        return url
    }

    private func loadFromSecurityScopedURL(_ url: URL) async throws -> GedcomData {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Try direct read first, then coordinated read fallback.
        let rawData: Data
        do {
            rawData = try tryReadData(at: url)
        } catch {
            rawData = try coordinatedRead(at: url)
        }

        return try await parse(data: rawData, sourceIdentifier: makeSourceIdentifier(for: url))
    }

    private func makeSourceIdentifier(for url: URL) -> String {
        let canonicalPath = url.standardizedFileURL.path
        if let identifier = canonicalPath.nilIfBlank {
            return "file::\(identifier)"
        }
        return url.absoluteString
    }

    private func displayName(for url: URL) -> String {
        #if os(macOS) || targetEnvironment(macCatalyst)
        if let resourceValues = try? url.resourceValues(forKeys: [.localizedNameKey]),
           let localizedName = resourceValues.localizedName {
            return localizedName
        }
        #endif
        return url.lastPathComponent
    }

    private func save(mode: SavedMode, bookmark: Data?, fileName: String?) {
        defaults.set(mode.rawValue, forKey: Keys.lastMode)
        defaults.set(bookmark, forKey: Keys.lastBookmark)
        defaults.set(fileName, forKey: Keys.lastFileName)
    }

    private func clearSavedSource() {
        defaults.removeObject(forKey: Keys.lastMode)
        defaults.removeObject(forKey: Keys.lastBookmark)
        defaults.removeObject(forKey: Keys.lastFileName)
    }

    // Repairs stale bookmarks by creating and saving a fresh one when needed.
    private func resolveBookmark(_ bookmark: Data, repairingIfStale: Bool) throws -> URL? {
        var isStale = false
        let resolutionOptions: URL.BookmarkResolutionOptions
#if os(macOS) || targetEnvironment(macCatalyst)
        resolutionOptions = [.withSecurityScope]
#else
        resolutionOptions = []
#endif
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: resolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            if repairingIfStale {
                // Attempt to create and persist a fresh bookmark from the resolved URL
                let creationOptions: URL.BookmarkCreationOptions
#if os(macOS) || targetEnvironment(macCatalyst)
                creationOptions = [.withSecurityScope]
#else
                creationOptions = []
#endif
                if let fresh = try? url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    defaults.set(fresh, forKey: Keys.lastBookmark)
                } else {
                    // If we cannot refresh, clear the saved one
                    defaults.removeObject(forKey: Keys.lastBookmark)
                }
            } else {
                defaults.removeObject(forKey: Keys.lastBookmark)
            }
        }
        return url
    }

    private enum SavedMode: String {
        case sample
        case file
    }

    private enum DocumentSource {
        case sample
        case file(bookmarkData: Data, fileName: String)

        var isSample: Bool {
            if case .sample = self { return true }
            return false
        }
    }

    private enum GedcomError: LocalizedError {
        case sampleMissing
        case unableToAccessFile
        case providerUnavailable

        var errorDescription: String? {
            switch self {
            case .sampleMissing:
                return String(
                    localized: "error.sample.missing_file",
                    defaultValue: "The bundled sample GEDCOM file is missing.",
                    bundle: .main
                )
            case .unableToAccessFile:
                return String(
                    localized: "error.access.unable_to_access_file",
                    defaultValue: "Unable to access the previously selected GEDCOM file.",
                    bundle: .main
                )
            case .providerUnavailable:
                return String(
                    localized: "error.provider.unavailable",
                    defaultValue: "The file is not currently available from its provider. Make it available offline in the provider app, then try again.",
                    bundle: .main
                )
            }
        }
    }

    private enum Sample {
        static let resourceName = "Sample-GEDCOM"
        static let `extension` = "ged"
        static let fileName = "Sample-GEDCOM.ged"
        static let sourceIdentifier = "sample::\(resourceName)"
    }

    private enum Unsupported {
        static var fileTypeMessage: String {
            String(
                localized: "error.unsupported_file_type",
                defaultValue: "Unsupported file type. Please choose a GEDCOM (.ged) file.",
                bundle: .main
            )
        }
    }

    private enum Keys {
        static let lastMode = "gedcomviewer.lastMode"
        static let lastBookmark = "gedcomviewer.lastBookmark"
        static let lastFileName = "gedcomviewer.lastFileName"
    }
}

// MARK: - Provider-aware read helpers

private extension GedcomViewModel {
    // Fast path: try reading if the file appears present; otherwise throw to allow fallback.
    func tryReadData(at url: URL) throws -> Data {
        let path = url.path
        let exists = FileManager.default.fileExists(atPath: path)
        if !exists {
            // Many third‑party providers report a path but the file isn't staged locally yet.
            throw GedcomError.providerUnavailable
        }
        return try Data(contentsOf: url)
    }

    // Coordinated read helps third‑party file providers (e.g., Google Drive) stage the file for reading.
    func coordinatedRead(at url: URL) throws -> Data {
        var readError: Error?
        var resultData: Data?

        let coordinator = NSFileCoordinator()
        let intent = NSFileAccessIntent.readingIntent(with: url, options: [])
        coordinator.coordinate(with: [intent], queue: fileCoordinationQueue) { _ in
            do {
                // After coordination, attempt to read again.
                resultData = try Data(contentsOf: intent.url)
            } catch {
                readError = error
            }
        }

        if let readError {
            // If the provider still didn't supply the file, surface a friendly error.
            if (readError as NSError).domain == NSCocoaErrorDomain && (readError as NSError).code == NSFileNoSuchFileError {
                throw GedcomError.providerUnavailable
            }
            throw readError
        }

        if let data = resultData {
            return data
        } else {
            throw GedcomError.providerUnavailable
        }
    }

    func bestUserMessage(for error: Error) -> String {
        if let gedError = error as? GedcomError {
            return gedError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
            return GedcomError.providerUnavailable.localizedDescription
        }
        let fallback = String(
            localized: "error.load.generic",
            defaultValue: "Unable to load GEDCOM file.",
            bundle: .main
        )
        return error.localizedDescription.nilIfBlank ?? fallback
    }

    func isSupportedGedcomFile(_ url: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare("ged") == .orderedSame
    }
}

struct GedcomUIState {
    var isLoading: Bool = false
    var data: GedcomData?
    var error: String?
    var needsFileSelection: Bool = true
    var currentFileName: String?
    var isSampleData: Bool = false
    var lastSuccessfulLoadID: UUID?
    var selectedIndividualId: String?
}
