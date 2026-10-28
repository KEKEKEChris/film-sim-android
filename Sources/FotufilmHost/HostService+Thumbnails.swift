import Foundation

/// The photo strip's pictures of files opened together but not yet decoded: only the photograph
/// being edited is decoded, the others show these until they are chosen. The photo library's grid
/// draws the files of the folders the host reads from these too.
extension HostService {
    /// Every film's picture of the shown photograph, in one call. The editor sends the same render
    /// request once per film; the scene is reduced once (the reduction is kept), and every answer
    /// comes back together. Asking one film at a time cost a crossing of the bridge each, which is
    /// what made the strip crawl as it scrolled, and one film that failed stopped the rest.
    func filmStrip(_ parameters: [String: Any]) throws -> Answer {
        let films = (parameters["films"] as? [String]) ?? []
        let requests = (parameters["requests"] as? [[String: Any]]) ?? []
        var images: [String: [UInt8]] = [:]
        var failed: [String: String] = [:]
        for (index, film) in films.enumerated() {
            guard index < requests.count else { break }
            // '' is Normal, the row without a film; a payload cannot be named ''.
            let name = film.isEmpty ? "none" : film
            do {
                let data = try JSONSerialization.data(withJSONObject: requests[index])
                guard let png = payload("preview", of: try render(data)) else {
                    failed[name] = "The develop answered without a picture."
                    continue
                }
                images[name] = png
            } catch {
                // One film's failure is its own: the strip keeps the others.
                failed[name] = (error as? HostEngine.Failure)?.description ?? "\(error)"
            }
        }
        return try answer(["films": films, "failed": failed], images: images)
    }

    /// A named byte range of an answer, as the editor reads it across the bridge.
    private func payload(_ name: String, of answer: Answer) -> [UInt8]? {
        guard let body = try? JSONSerialization.jsonObject(with: answer.json) as? [String: Any],
              let ranges = body["payloads"] as? [String: [Int]],
              let range = ranges[name], range.count == 2,
              range[0] >= 0, range[1] >= 0, range[0] + range[1] <= answer.payload.count
        else { return nil }
        return Array(answer.payload[range[0]..<(range[0] + range[1])])
    }

    func thumbnail(_ parameters: [String: Any], payload: UnsafeRawBufferPointer?) throws -> Answer {
        let maxEdge = max(16, min(1024, parameters["maxEdge"] as? Int ?? 256))
        let picture: (pixels: [UInt8], width: Int, height: Int)
        if let path = parameters["path"] as? String, !path.isEmpty {
            picture = try thumbnail(of: URL(fileURLWithPath: path), maxEdge: maxEdge)
        } else if let payload, payload.count > 0 {
            // Bytes handed over (a photo-library file): read from a private copy, whose extension
            // is the decoders' hint.
            let name = parameters["name"] as? String ?? "photo"
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("fotufilm-import", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent(
                UUID().uuidString + "." + URL(fileURLWithPath: name).pathExtension)
            try Data(bytes: payload.baseAddress!, count: payload.count).write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            picture = try thumbnail(of: file, maxEdge: maxEdge)
        } else {
            throw HostEngine.Failure(description: "No file was named.")
        }
        // Pixels as they are for a caller that draws them itself (the Flutter editor), else a PNG.
        if parameters["pixels"] as? Bool == true {
            return try answer(["width": picture.width, "height": picture.height, "format": "rgba"],
                              images: ["thumbnail": picture.pixels])
        }
        let png = picture.pixels.withUnsafeBytes {
            StoredPNG.encode($0.baseAddress!, width: picture.width, height: picture.height,
                             rowBytes: picture.width * 4)
        }
        return try answer(["width": picture.width, "height": picture.height],
                          images: ["thumbnail": png])
    }

    /// A movie's first frame decoded small, a still's embedded or reduced preview.
    private func thumbnail(of url: URL, maxEdge: Int) throws
        -> (pixels: [UInt8], width: Int, height: Int) {
        if let videos = HostPlatform.current.videoSource, videos.isMovie(url) {
            let source = try videos.open(url)
            let size = AreaResample.size(width: source.width, height: source.height, maxEdge: maxEdge)
            let frame = try source.frame(at: source.start, width: size.width, height: size.height,
                                         interpretation: .standard, displayCodes: true)
            if let codes = frame.display8 { return (codes.bytes, frame.width, frame.height) }
            let image = HostImage(rgba: frame.rgba, width: frame.width, height: frame.height,
                                  contentHeadroom: 1)
            return (image.display(image.scene(width: frame.width, height: frame.height),
                                  width: frame.width, height: frame.height),
                    frame.width, frame.height)
        }
        guard let thumbnails = HostPlatform.current.thumbnails else {
            throw HostEngine.Failure(description: "This host draws no thumbnails.")
        }
        return try thumbnails.thumbnail(url, maxEdge: maxEdge)
    }
}
