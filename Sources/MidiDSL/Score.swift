import Foundation

public protocol Score {
    init()
    var session: Session { get }
}

public extension Score {
    static func main() {
        ScoreRunner.run { Self().session }
    }
}

public enum ScoreRunner {

    public static func run(_ build: () -> Session) {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--time-signature"), flag + 1 < arguments.count {
            let parts = arguments[flag + 1].split(separator: "/").compactMap { Int($0) }
            if parts.count == 2, parts[0] > 0, parts[1] > 0 {
                SectionBuilder.timeSignature = TimeSignature(parts[0], parts[1])
            }
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(build())
        } catch {
            data = Data("{\"error\": \"\(error)\"}".utf8)
        }

        if let flag = arguments.firstIndex(of: "--session-json"), flag + 1 < arguments.count {
            try? data.write(to: URL(fileURLWithPath: arguments[flag + 1]))
        } else {
            FileHandle.standardOutput.write(data)
        }
    }
}
