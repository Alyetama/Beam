import Foundation
import Network

enum RFBError: Error, LocalizedError {
    case connectionClosed
    case handshakeFailed(String)
    case authFailed(String)
    case unsupported(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .connectionClosed:        return "The connection was closed."
        case .handshakeFailed(let m):  return "Handshake failed: \(m)"
        case .authFailed(let m):       return "Authentication failed: \(m)"
        case .unsupported(let m):      return "Unsupported: \(m)"
        case .cancelled:               return "Cancelled."
        }
    }
}

/// A thin async wrapper around `NWConnection` that vends *exact* byte counts.
/// All reads happen from a single protocol task, so the buffer needs no locking.
final class ByteChannel {
    private let connection: NWConnection
    private var buffer = Data()

    init(host: String, port: UInt16) {
        let params = NWParameters.tcp
        // Disable Nagle's algorithm so small pointer/key packets are sent immediately.
        if let tcpOptions = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOptions.noDelay = true
        }
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: params
        )
    }

    func connect(timeout: TimeInterval = 15) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var finished = false
            let finish: (Result<Void, Error>) -> Void = { result in
                guard !finished else { return }
                finished = true
                switch result {
                case .success: cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(()))
                case .failed(let error):
                    finish(.failure(error))
                case .cancelled:
                    finish(.failure(RFBError.cancelled))
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(.failure(RFBError.handshakeFailed("Connection timed out")))
            }
        }
    }

    /// Read exactly `count` bytes, awaiting more from the socket as needed.
    func read(_ count: Int) async throws -> Data {
        while buffer.count < count {
            let chunk = try await receiveChunk()
            buffer.append(chunk)
        }
        let result = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(result)
    }

    func readUInt8() async throws -> UInt8 { try await read(1)[0] }

    func readUInt16() async throws -> UInt16 {
        let d = try await read(2)
        return (UInt16(d[0]) << 8) | UInt16(d[1])
    }

    func readUInt32() async throws -> UInt32 {
        let d = try await read(4)
        return (UInt32(d[0]) << 24) | (UInt32(d[1]) << 16) | (UInt32(d[2]) << 8) | UInt32(d[3])
    }

    func readInt32() async throws -> Int32 { Int32(bitPattern: try await readUInt32()) }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 18) { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    cont.resume(returning: data)
                } else if isComplete {
                    cont.resume(throwing: RFBError.connectionClosed)
                } else {
                    cont.resume(returning: Data())
                }
            }
        }
    }

    /// Fire-and-forget send (safe to call from any thread).
    func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func close() {
        connection.cancel()
    }
}
