import Foundation
import CSupertonic

final class Session {
    let handle: OpaquePointer
    let runtime: Runtime

    init(_ path: URL, runtime: Runtime, threads: Int) throws {
        self.runtime = runtime
        var error: UnsafeMutablePointer<CChar>?
        handle = try requireRuntimeResult(
            supertonic_session_create(runtime.handle, path.path, Int32(threads), &error), error: error)
    }

    func run(_ inputs: [(name: String, tensor: Tensor)], output: String) throws -> Tensor {
        let names = inputs.map { strdup($0.name) }
        defer { names.forEach { free($0) } }
        let immutableNames = names.map { $0.map { UnsafePointer($0) } }
        let tensors = inputs.map { Optional($0.tensor.handle) }
        var error: UnsafeMutablePointer<CChar>?
        let result = supertonic_session_run(handle, immutableNames, tensors, inputs.count, output, &error)
        return Tensor(handle: try requireRuntimeResult(result, error: error), runtime: runtime)
    }

    deinit { supertonic_session_release(handle) }
}
