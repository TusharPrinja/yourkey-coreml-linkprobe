// THE TRIPWIRE: an UNGUARDED import. This file cannot compile unless the
// spm_dependency in the podspec truly linked the package to THIS pod target.
// Compile success on CI = the wall is crossed; build 35 is safe to fire.
import CoreMLLLM

@available(iOS 18.0, *)
enum LinkTripwire {
    static func touch() async throws {
        _ = try await CoreMLLLM.load(repo: "qwen2.5-0.5b")
    }
}
