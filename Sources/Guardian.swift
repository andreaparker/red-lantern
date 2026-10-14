import Foundation

final class Guardian {
    private let task = Process()
    private let pipe = Pipe()
    private var stopped = false

    init(tables: [UInt32: GammaTable]) throws {
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/LanternGuardian")
        task.executableURL = executable
        task.standardInput = pipe
        task.standardOutput = FileHandle.nullDevice
        try task.run()
        try pipe.fileHandleForWriting.write(contentsOf: Self.encode(tables))
    }

    private static func encode(_ tables: [UInt32: GammaTable]) -> Data {
        var data = bytes(UInt32(tables.count))
        for (id, table) in tables {
            data.append(bytes(id))
            data.append(bytes(UInt32(table.red.count)))
            data.append(table.red.withUnsafeBytes { Data($0) })
            data.append(table.green.withUnsafeBytes { Data($0) })
            data.append(table.blue.withUnsafeBytes { Data($0) })
        }
        return data
    }

    private static func bytes(_ value: UInt32) -> Data {
        var number = value
        return withUnsafeBytes(of: &number) { Data($0) }
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        try? pipe.fileHandleForWriting.write(contentsOf: Data([1]))
        try? pipe.fileHandleForWriting.close()
    }

    func simulateCrash() -> Bool {
        try? pipe.fileHandleForWriting.close()
        let deadline = Date().addingTimeInterval(3)
        while task.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.03) }
        if task.isRunning { task.terminate(); return false }
        stopped = true
        return task.terminationStatus == 0
    }
}
