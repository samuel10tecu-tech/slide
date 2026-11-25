import Foundation

@main
enum LinuxMain {
    static func main() {
        do {
            try LogicChecks.all()
            print("OK — logique Slide")
        } catch {
            fputs("ÉCHEC \(error)\n", stderr)
            exit(1)
        }
    }
}
