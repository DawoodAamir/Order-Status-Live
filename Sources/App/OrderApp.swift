import ActivityKit
import SwiftUI
import WidgetKit

@MainActor final class OrderStore: ObservableObject {
  @Published var order = Order()
  @Published var endpoint = ""
  @Published var token = ""
  @Published var sample = true
  @Published var status = "Sample order · saved on this device"
  @Published var error: String?
  @Published var busy = false
  private var connection: (origin: URL, token: String)?
  private var generation = UUID()
  private var file: URL {
    FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(
        (ProcessInfo.processInfo.environment["PORTFOLIO_UI_TEST"].map { "UITests/" + $0 + "/" }
          ?? "")
          + "OrderStatus/" + (sample ? "sample" : "server") + ".json")
  }
  private var canSave = true
  init() {
    do { order = try JSONDecoder().decode(Order.self, from: Data(contentsOf: file)) } catch let e
      as CocoaError where e.code == .fileReadNoSuchFile
    {} catch {
      canSave = false
      self.error = "Saved order could not be read. The original file is preserved."
    }
  }
  func save(_ next: Order) throws {
    guard canSave else { throw CocoaError(.fileWriteNoPermission) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(next)
    try data.write(to: file, options: [.atomic, .completeFileProtection])
    order = next
    if let group = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.dd.orderstatus")
    {
      try data.write(to: group.appendingPathComponent("order.json"), options: .atomic)
    }
    WidgetCenter.shared.reloadTimelines(ofKind: "OrderStatus")
    if #available(iOS 16.2, *) { Task { await updateActivities() } }
  }
  func cancelConnection() {
    generation = UUID()
    connection = nil
  }
  func advance() {
    guard sample else { return }
    do {
      var next = order
      next.advance()
      try save(next)
    } catch { self.error = error.localizedDescription }
  }
  func refresh() async {
    guard !sample, !busy else { return }
    guard let connection else { return }
    let base = connection.origin
    let token = connection.token
    let requestGeneration = generation
    busy = true
    defer { busy = false }
    do {
      var req = URLRequest(url: base.appendingPathComponent("orders/OS-2048"))
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      req.timeoutInterval = 15
      let (data, response) = try await URLSession.shared.data(for: req)
      guard generation == requestGeneration, !sample else { throw CancellationError() }
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw URLError(.userAuthenticationRequired)
      }
      let incoming = try JSONDecoder().decode(Order.self, from: data)
      var next = order
      try next.accept(incoming)
      try save(next)
      status = "Reference server · last checked \(Date().formatted(date:.omitted,time:.shortened))"
    } catch {
      self.error = error.localizedDescription
      status = "Update unavailable · cached order shown"
    }
  }
  func connect() async {
    guard !busy else { return }
    guard let url = URL(string: endpoint), url.host != nil, url.user == nil, url.password == nil,
      url.path.isEmpty, url.query == nil, url.fragment == nil,
      url.scheme == "https" || (url.scheme == "http" && url.host == "localhost")
    else {
      error = "Use an HTTPS origin or http://localhost:8092 in Simulator."
      return
    }
    let previous = order
    generation = UUID()
    connection = (url, token)
    sample = false
    error = nil
    do { order = try JSONDecoder().decode(Order.self, from: Data(contentsOf: file)) } catch let e
      as CocoaError where e.code == .fileReadNoSuchFile
    { order = Order() } catch {
      sample = true
      order = previous
      self.error = "Saved server order is unreadable. The original file is preserved."
      return
    }
    await refresh()
    if error != nil {
      sample = true
      order = previous
      connection = nil
      status = "Sample order · saved on this device"
    }
  }
  @available(iOS 16.2, *) func startActivity() {
    do {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        throw NSError(domain: "Enable Live Activities in system settings.", code: 1)
      }
      if !Activity<OrderAttributes>.activities.isEmpty { return }
      _ = try Activity.request(
        attributes: OrderAttributes(orderID: order.id),
        content: ActivityContent(
          state: OrderAttributes.ContentState(stage: order.stage, title: order.title),
          staleDate: Date().addingTimeInterval(900)), pushType: nil)
      status = "Live Activity started"
    } catch { self.error = error.localizedDescription }
  }
  @available(iOS 16.2, *) func updateActivities() async {
    let content = ActivityContent(
      state: OrderAttributes.ContentState(stage: order.stage, title: order.title),
      staleDate: Date().addingTimeInterval(900))
    for activity in Activity<OrderAttributes>.activities {
      if order.stage == 4 {
        await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(300)))
      } else {
        await activity.update(content)
      }
    }
  }
  @available(iOS 16.2, *) func endActivities() async {
    for activity in Activity<OrderAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
@main struct OrderApp: App {
  @StateObject var store = OrderStore()
  var body: some Scene { WindowGroup { OrderView().environmentObject(store).tint(.indigo) } }
}
struct OrderView: View {
  @EnvironmentObject var store: OrderStore
  @State var settings = false
  @Environment(\.scenePhase) var phase
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            VStack(alignment: .leading, spacing: 6) {
              Text("Your order").font(.largeTitle.weight(.semibold))
              Text(store.order.id).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "shippingbox").font(.system(size: 42)).foregroundColor(.indigo)
          }
          Text("A sample delivery from North Street Supply").font(.subheadline).foregroundColor(
            .secondary)
          Text(store.order.title).font(.title.weight(.semibold))
          Text(store.status).font(.caption).foregroundColor(.secondary)
          VStack(alignment: .leading, spacing: 22) {
            ForEach(
              Array(
                ["Confirmed", "Preparing", "Ready for dispatch", "On the way", "Delivered"]
                  .enumerated()), id: \.offset
            ) { index, title in
              HStack(spacing: 16) {
                Image(systemName: index <= store.order.stage ? "checkmark.circle.fill" : "circle")
                  .font(.title2).foregroundColor(index <= store.order.stage ? .indigo : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                  Text(title).font(.headline)
                  Text(
                    index == store.order.stage
                      ? "Current status" : index < store.order.stage ? "Completed" : "Upcoming"
                  ).font(.caption).foregroundColor(.secondary)
                }
              }.accessibilityElement(children: .combine)
            }
          }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(
            Color(UIColor.secondarySystemBackground)
          ).cornerRadius(16)
          if store.sample {
            Button("Advance sample order") { store.advance() }.buttonStyle(.borderedProminent)
              .disabled(store.order.stage == 4)
            Text(
              "Simulation: this button advances a local order. Server-connected orders are read-only."
            ).font(.footnote).foregroundColor(.secondary)
          } else {
            Button("Refresh status") { Task { await store.refresh() } }.disabled(store.busy)
          }
          if #available(iOS 16.2, *) {
            HStack {
              Button("Start Live Activity") { store.startActivity() }
              Spacer()
              Button("End activity") { Task { await store.endActivities() } }
            }.buttonStyle(.bordered)
          } else {
            Text(
              "Live Activities require iOS 16.2 or newer. Order tracking and the home-screen widget work on iOS 15."
            ).font(.footnote).foregroundColor(.secondary)
          }
          Text(
            "Updates refresh while this screen is active. A production service can deliver remote Live Activity updates through APNs; this reference app uses local ActivityKit updates."
          ).font(.footnote).foregroundColor(.secondary)
        }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
      }.navigationTitle("Order Status").navigationBarTitleDisplayMode(.inline).toolbar {
        Button {
          settings = true
        } label: {
          Image(systemName: "gearshape")
        }.accessibilityLabel("Connection settings")
      }
    }
    .navigationViewStyle(.stack).task {
      while !Task.isCancelled {
        if phase == .active { await store.refresh() }
        try? await Task.sleep(nanoseconds: 5_000_000_000)
      }
    }
    .sheet(isPresented: $settings) {
      NavigationView {
        Form {
          Section("Reference service") {
            TextField("http://localhost:8092", text: $store.endpoint).textInputAutocapitalization(
              .never
            ).disableAutocorrection(true)
            SecureField("Read token", text: $store.token)
            Button("Connect") {
              Task {
                await store.connect()
                if !store.sample { settings = false }
              }
            }
            Text(
              "Start Server/server.py and use sample-reader. Operators update status through the API, not the client."
            ).font(.footnote)
          }
          Section {
            Button("Reset sample order") {
              store.sample = true
              store.cancelConnection()
              do {
                try store.save(Order())
                store.status = "Sample order · saved on this device"
              } catch { store.error = error.localizedDescription }
              settings = false
            }
          }
        }.navigationTitle("Connection").toolbar { Button("Done") { settings = false } }
      }
    }
    .alert(
      "Tracking needs attention",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }
}
