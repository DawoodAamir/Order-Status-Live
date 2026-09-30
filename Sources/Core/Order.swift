import Foundation

struct Order: Codable, Equatable {
  var id = "OS-2048"
  var stage = 0
  var revision = 0
  var updatedAt = Date().timeIntervalSince1970
  var title: String {
    ["Confirmed", "Preparing", "Ready for dispatch", "On the way", "Delivered"][
      min(4, max(0, stage))]
  }
  mutating func advance() {
    guard stage < 4 else { return }
    stage += 1
    revision += 1
    updatedAt = Date().timeIntervalSince1970
  }
  mutating func accept(_ incoming: Order) throws {
    guard incoming.id == id, (0...4).contains(incoming.stage), incoming.stage >= stage,
      incoming.revision >= revision
    else { throw NSError(domain: "Stale or invalid order update", code: 1) }
    self = incoming
  }
}
#if os(iOS) && canImport(ActivityKit)
  import ActivityKit
  @available(iOS 16.1, *)
  struct OrderAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
      var stage: Int
      var title: String
    }
    var orderID: String
  }
#endif
