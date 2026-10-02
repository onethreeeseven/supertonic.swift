import Foundation
import CSupertonic

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

    private static func create<Value>(_ values: [Value], shape: [Int64], isInteger: Bool, runtime: Runtime)
        throws -> OpaquePointer
    {
        guard !shape.isEmpty, shape.allSatisfy({ $0 > 0 }),
            shape.reduce(Int64(1), *) == values.count
        else {
            throw SupertonicError.invalidModel("Tensor dimensions do not match its values")
        }
        var error: UnsafeMutablePointer<CChar>?
        let result = values.withUnsafeBytes { bytes in
            supertonic_tensor_create(
                runtime.handle, bytes.baseAddress, bytes.count, shape, shape.count, isInteger ? 1 : 0, &error)
        }
        return try requireRuntimeResult(result, error: error)
    }

    func floats() throws -> [Float] {
        var count = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = supertonic_tensor_floats(handle, &count, &error)
        let pointer = try requireRuntimeResult(result, error: error, fallback: "Missing tensor data")
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    deinit { supertonic_tensor_release(handle) }
}
