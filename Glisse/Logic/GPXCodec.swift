import Foundation

enum GPXError: Error, Equatable {
    case empty
    case unreadable
}

enum GPXCodec {
    static func encode(archive: SessionArchive) -> String {
        let name = archive.resort.isEmpty ? "Glisse" : archive.resort
        let stamp = iso.string(from: archive.startedAt)
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Glisse" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escape(name))</name>
            <time>\(stamp)</time>
          </metadata>
          <trk>
            <name>\(escape(name))</name>
            <trkseg>

        """
        for sample in archive.samples {
            let time = iso.string(from: sample.time)
            xml += """
                <trkpt lat="\(format(sample.latitude))" lon="\(format(sample.longitude))">
                  <ele>\(format(sample.rawAltitude))</ele>
                  <time>\(time)</time>
                  <extensions>
                    <speed>\(format(sample.speed))</speed>
                    <phase>\(sample.phase.rawValue)</phase>
                  </extensions>
                </trkpt>

            """
        }
        xml += """
            </trkseg>
          </trk>
        </gpx>
        """
        return xml
    }

    static func parse(_ xml: String, missingTimeStart: Date = Date()) throws -> [GeoSample] {
        guard xml.contains("trkpt") else { throw GPXError.empty }
        guard let regex = try? NSRegularExpression(
            pattern: "<trkpt\\b([^>]*)>(.*?)</trkpt>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else {
            throw GPXError.unreadable
        }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let matches = regex.matches(in: xml, range: range)
        if matches.isEmpty { throw GPXError.empty }

        var samples: [GeoSample] = []
        var missingIndex = 0
        for match in matches {
            guard let attrRange = Range(match.range(at: 1), in: xml),
                  let bodyRange = Range(match.range(at: 2), in: xml)
            else { continue }
            let attrs = String(xml[attrRange])
            let body = String(xml[bodyRange])
            guard let lat = attribute("lat", in: attrs),
                  let lon = attribute("lon", in: attrs)
            else { continue }
            let ele = firstDouble(tag: "ele", in: body) ?? 0
            let speed = firstDouble(tag: "speed", in: body)
            let time: Date
            if let rawTime = firstText(tag: "time", in: body), let parsed = parseTime(rawTime) {
                time = parsed
            } else {
                time = missingTimeStart.addingTimeInterval(Double(missingIndex))
                missingIndex += 1
            }
            let plausibleSpeed: Double?
            if let speed, speed.isFinite, speed >= 0, speed < 80 {
                plausibleSpeed = speed
            } else {
                plausibleSpeed = nil
            }
            samples.append(GeoSample(
                time: time,
                latitude: lat,
                longitude: lon,
                altitude: ele,
                horizontalAccuracy: 5,
                gpsSpeed: plausibleSpeed
            ))
        }
        if samples.isEmpty { throw GPXError.empty }
        return samples
    }

    private static func attribute(_ name: String, in text: String) -> Double? {
        let pattern = "\(name)\\s*=\\s*[\"']([+-]?[0-9]*\\.?[0-9]+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[range])
    }

    private static func firstText(tag: String, in body: String) -> String? {
        let pattern = "<(?:\\w+:)?\(tag)\\b[^>]*>(.*?)</(?:\\w+:)?\(tag)>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ),
            let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
            let range = Range(match.range(at: 1), in: body)
        else { return nil }
        return String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstDouble(tag: String, in body: String) -> Double? {
        guard let text = firstText(tag: tag, in: body) else { return nil }
        return Double(text)
    }

    private static func parseTime(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func format(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
