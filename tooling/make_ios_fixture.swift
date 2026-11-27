import Foundation

/// Writes an iOS-encoded sample day for the Android interoperability test:
/// swiftc -parse-as-library -o /tmp/fixture Slide/Logic/*.swift tooling/make_ios_fixture.swift && /tmp/fixture <out.slide>
@main
enum MakeIOSFixture {
    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first ?? "ios-sample.slide"
        let archive = SampleDay.make(on: Date(timeIntervalSince1970: 1_763_000_000))
        try SessionFile.encode(archive).write(to: URL(fileURLWithPath: path))
        print("wrote \(path): \(archive.runs.count) runs, \(archive.samples.count) points")
    }
}
