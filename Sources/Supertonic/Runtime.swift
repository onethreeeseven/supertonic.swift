import Foundation
import CSupertonic

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
        handle = try requireRuntimeResult(result, error: error)
    }

    deinit { supertonic_runtime_release(handle) }
}

func requireRuntimeResult<Value>(
    _ result: Value?,
    error: UnsafeMutablePointer<CChar>?,
    fallback: String = "Runtime returned no result"
) throws -> Value {
    defer { supertonic_error_release(error) }
    guard let result else {
        throw SupertonicError.runtime(error.map { String(cString: $0) } ?? fallback)
    }
    return result
}
