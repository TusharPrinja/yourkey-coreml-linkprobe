// PROBE-ONLY tripwire: the unconditional import the production bridge cannot
// carry (it must compile package-less too). Compile success = the link is real.
import CoreMLLLM
enum YKLinkTripwire {
  @available(iOS 18.0, *)
  static func touch() async throws {
    _ = try await CoreMLLLM.load(repo: "qwen2.5-0.5b")
  }
}
