import Foundation
import CSupertonic

public enum SupertonicError: Error, LocalizedError, Sendable {
    case runtime(String)
    case invalidModel(String)
    case download(String, Int)

    public var errorDescription: String? {
        switch self {
        case .runtime(let message): return "ONNX Runtime: \(message)"
        case .invalidModel(let message): return "Invalid Supertonic model: \(message)"
        case .download(let path, let status): return "Model download failed for \(path): HTTP \(status)"
        }
    }
}

final class Runtime {
    let handle: OpaquePointer

    init() throws {
        var error: UnsafeMutablePointer<CChar>?
        #if os(Linux)
        #if arch(x86_64)
        let architecture = "x86_64"
        #elseif arch(arm64)
        let architecture = "arm64"
        #else
        throw SupertonicError.runtime("Linux requires x86_64 or ARM64")
        #endif
        guard let directory = Bundle.module.resourceURL else {
            throw SupertonicError.runtime("Bundled Linux runtime is missing")
        }
        let path = directory.appendingPathComponent("Runtime/\(architecture)/libonnxruntime.so").path
        let result = supertonic_runtime_create(path, &error)
        #else
        let result = supertonic_runtime_create(nil, &error)
        #endif
        handle = try requireHandle(result, error: error)
    }

    deinit { supertonic_runtime_release(handle) }
}

func requireHandle(_ handle: OpaquePointer?, error: UnsafeMutablePointer<CChar>?) throws -> OpaquePointer {
    defer { supertonic_error_release(error) }
    guard let handle else {
        throw SupertonicError.runtime(error.map { String(cString: $0) } ?? "Runtime returned no result")
    }
    return handle
}

final class Tensor {
    let handle: OpaquePointer
    let runtime: Runtime

    init(handle: OpaquePointer, runtime: Runtime) {
        self.handle = handle
        self.runtime = runtime
    }

    convenience init(_ values: [Float], shape: [Int64], runtime: Runtime) throws {
        let handle = try Self.create(values, shape: shape, isInteger: false, runtime: runtime)
        self.init(handle: handle, runtime: runtime)
    }

    convenience init(_ values: [Int64], shape: [Int64], runtime: Runtime) throws {
        let handle = try Self.create(values, shape: shape, isInteger: true, runtime: runtime)
        self.init(handle: handle, runtime: runtime)
    }

    private static func create<Value>(_ values: [Value], shape: [Int64], isInteger: Bool, runtime: Runtime) throws -> OpaquePointer {
        guard !shape.isEmpty, shape.allSatisfy({ $0 > 0 }),
              shape.reduce(Int64(1), *) == values.count else {
            throw SupertonicError.invalidModel("Tensor dimensions do not match its values")
        }
        var error: UnsafeMutablePointer<CChar>?
        let result = values.withUnsafeBytes { bytes in
            supertonic_tensor_create(runtime.handle, bytes.baseAddress, bytes.count, shape, shape.count, isInteger ? 1 : 0, &error)
        }
        return try requireHandle(result, error: error)
    }

    func floats() throws -> [Float] {
        var count = 0
        var error: UnsafeMutablePointer<CChar>?
        let pointer = supertonic_tensor_floats(handle, &count, &error)
        defer { supertonic_error_release(error) }
        guard let pointer else {
            throw SupertonicError.runtime(error.map { String(cString: $0) } ?? "Missing tensor data")
        }
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    deinit { supertonic_tensor_release(handle) }
}

final class Session {
    let handle: OpaquePointer
    let runtime: Runtime

    init(_ path: URL, runtime: Runtime, threads: Int) throws {
        self.runtime = runtime
        var error: UnsafeMutablePointer<CChar>?
        handle = try requireHandle(supertonic_session_create(runtime.handle, path.path, Int32(threads), &error), error: error)
    }

    func run(_ inputs: [(String, Tensor)], output: String) throws -> Tensor {
        let names = inputs.map { strdup($0.0) }
        defer { names.forEach { free($0) } }
        let immutableNames = names.map { $0.map { UnsafePointer($0) } }
        let tensors = inputs.map { Optional($0.1.handle) }
        var error: UnsafeMutablePointer<CChar>?
        let result = supertonic_session_run(handle, immutableNames, tensors, inputs.count, output, &error)
        return Tensor(handle: try requireHandle(result, error: error), runtime: runtime)
    }

    deinit { supertonic_session_release(handle) }
}
