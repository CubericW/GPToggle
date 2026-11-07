import Foundation
import Darwin

/// GlobalProtect 在本机以两个 LaunchAgent 跑在当前用户的图形会话（gui/<uid>）里：
///   com.paloaltonetworks.gp.pangpa → GlobalProtect 界面（KeepAlive，被杀会立刻重启）
///   com.paloaltonetworks.gp.pangps → PanGPS 后台服务
/// 所以"关闭"= 把它们从 launchd 卸载（bootout），"开启"= 重新加载（bootstrap），都不需要管理员密码。
enum GlobalProtect {
    static let appPath = "/Applications/GlobalProtect.app"

    struct Agent {
        let label: String
        var plist: String { "/Library/LaunchAgents/\(label).plist" }
    }

    /// 关闭时按此顺序（先界面、后服务），开启时反过来
    static let agents = [Agent(label: "com.paloaltonetworks.gp.pangpa"),
                         Agent(label: "com.paloaltonetworks.gp.pangps")]

    private static let domain = "gui/\(getuid())"

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: appPath) }

    // MARK: 进程检测

    struct Snapshot {
        var pids: [pid_t] = []
        var hasUI = false
        var hasService = false
        var isRunning: Bool { hasUI || hasService }
    }

    /// 遍历所有进程，找出 GlobalProtect 界面和 PanGPS（直接读内核进程表，不启动子进程，开销很小）
    static func snapshot() -> Snapshot {
        var snap = Snapshot()
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return snap }
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 64)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        var path = [UInt8](repeating: 0, count: 4096)
        for pid in pids.prefix(Int(max(count, 0))) where pid > 0 {
            let length = proc_pidpath(pid, &path, UInt32(path.count))
            guard length > 0 else { continue }
            let executable = String(decoding: path[..<Int(length)], as: UTF8.self)
            if executable == appPath + "/Contents/MacOS/GlobalProtect" {
                snap.hasUI = true
                snap.pids.append(pid)
            } else if executable == appPath + "/Contents/Resources/PanGPS" {
                snap.hasService = true
                snap.pids.append(pid)
            }
        }
        return snap
    }

    static func isLoaded(_ agent: Agent) -> Bool {
        launchctl("print", "\(domain)/\(agent.label)", quiet: true).status == 0
    }

    // MARK: 开关（耗时操作，需在后台线程调用；返回 nil 表示成功，否则是给用户看的错误说明）

    static func stop() -> String? {
        Log.write("—— 关闭 GlobalProtect")
        let loaded = agents.filter(isLoaded)
        for agent in loaded {
            launchctl("bootout", "\(domain)/\(agent.label)")
        }
        // bootout 会立即返回，进程是异步退出的（PanGPS 最多可能要 20 秒）
        if !loaded.isEmpty, waitUntil(timeout: 25, { !snapshot().isRunning }) { return nil }

        // 兜底：旧式 unload，再结束残留进程（例如手动双击打开的界面）
        Log.write("进程仍在，尝试兜底方式")
        for agent in agents { launchctl("unload", agent.plist) }
        for pid in snapshot().pids { kill(pid, SIGTERM) }
        if waitUntil(timeout: 8, { !snapshot().isRunning }) { return nil }

        let left = snapshot().pids.map(String.init).joined(separator: ", ")
        return "仍有 GlobalProtect 进程在运行（PID \(left)）。"
    }

    static func start() -> String? {
        Log.write("—— 开启 GlobalProtect")
        var failures: [String] = []
        for agent in agents.reversed() {
            if isLoaded(agent) {
                launchctl("kickstart", "\(domain)/\(agent.label)")
                continue
            }
            var result = launchctl("bootstrap", domain, agent.plist)
            if result.status != 0 && !isLoaded(agent) {
                // 可能被 launchctl disable 过：解除禁用后再试一次
                launchctl("enable", "\(domain)/\(agent.label)")
                result = launchctl("bootstrap", domain, agent.plist)
            }
            if result.status != 0 && !isLoaded(agent) {
                failures.append("\(agent.label)：\(result.output.isEmpty ? "退出码 \(result.status)" : result.output)")
            }
        }
        if waitUntil(timeout: 15, { let s = snapshot(); return s.hasUI && s.hasService }) { return nil }
        if failures.isEmpty && snapshot().isRunning { return nil }
        return failures.isEmpty ? "等了 15 秒，GlobalProtect 仍未运行。" : failures.joined(separator: "\n")
    }

    // MARK: 工具

    @discardableResult
    private static func launchctl(_ args: String..., quiet: Bool = false) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = quiet ? FileHandle.nullDevice : pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            Log.write("无法执行 launchctl \(args.joined(separator: " "))：\(error.localizedDescription)")
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if !quiet {
            Log.write("launchctl \(args.joined(separator: " ")) → \(process.terminationStatus)" + (output.isEmpty ? "" : "  \(output)"))
        }
        return (process.terminationStatus, output)
    }

    private static func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return true
    }
}

/// 简单的文件日志：~/Library/Logs/GPToggle.log
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/GPToggle.log")

    private static let queue = DispatchQueue(label: "GPToggle.log")
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func write(_ message: String) {
        let now = Date()
        queue.async {
            let data = Data("\(formatter.string(from: now))  \(message)\n".utf8)
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    /// 超过 1 MB 就清空，避免无限增长
    static func trimIfNeeded() {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
        if size > 1_000_000 { try? FileManager.default.removeItem(at: url) }
    }
}
