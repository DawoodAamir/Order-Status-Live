import ActivityKit
import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
  let date: Date
  let order: Order
}
struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry { Entry(date: Date(), order: Order()) }
  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(read())
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(900))))
  }
  func read() -> Entry {
    let order =
      FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.dd.orderstatus"
      ).flatMap { try? Data(contentsOf: $0.appendingPathComponent("order.json")) }.flatMap {
        try? JSONDecoder().decode(Order.self, from: $0)
      } ?? Order()
    return Entry(date: Date(), order: order)
  }
}
struct OrderWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "OrderStatus", provider: Provider()) { entry in
      WidgetView(order: entry.order)
    }.configurationDisplayName("Order Status").description("The latest cached delivery status.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
struct WidgetView: View {
  let order: Order
  var body: some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    } else {
      content.padding().background(Color(UIColor.systemBackground))
    }
  }
  var content: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(order.id, systemImage: "shippingbox").font(.caption)
      Text(order.title).font(.headline)
      ProgressView(value: Double(order.stage), total: 4).tint(.indigo)
      Text(
        "Last update \(Date(timeIntervalSince1970:order.updatedAt).formatted(date:.omitted,time:.shortened))"
      ).font(.caption2).foregroundColor(.secondary)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
@available(iOS 16.2, *)
struct OrderLiveWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: OrderAttributes.self) { context in
      VStack(alignment: .leading, spacing: 12) {
        Label(context.attributes.orderID, systemImage: "shippingbox").font(.caption)
        Text(context.state.title).font(.headline)
        ProgressView(value: Double(context.state.stage), total: 4)
      }.padding().activityBackgroundTint(Color(UIColor.secondarySystemBackground))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) { Image(systemName: "shippingbox") }
        DynamicIslandExpandedRegion(.trailing) { Text(context.attributes.orderID).font(.caption) }
        DynamicIslandExpandedRegion(.bottom) { Text(context.state.title).font(.headline) }
      } compactLeading: {
        Image(systemName: "shippingbox")
      } compactTrailing: {
        Text("\(context.state.stage+1)/5")
      } minimal: {
        Image(systemName: "shippingbox")
      }
    }
  }
}
@main struct OrderWidgets: WidgetBundle {
  var body: some Widget {
    OrderWidget()
    if #available(iOS 16.2, *) { OrderLiveWidget() }
  }
}
