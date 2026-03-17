import Foundation
import Combine

/// WebSocket events published to subscribers
enum WebSocketEvent {
    case newBlock(NewBlockData)
    case transactionConfirmed(txid: String, blockHeight: Int?)
    case addressUpdated(address: String)
    case projectedBlocks([ProjectedBlock])
    case stats(MempoolStats)
    case hashrate([Hashrate])
    case connected
    case disconnected
}

/// Data received when a new block is mined
struct NewBlockData {
    let height: Int
    let hash: String
    let timestamp: Int
    let txCount: Int
    let size: Int
}

/// WebSocket service for real-time mempool.space updates
class MempoolWebSocketService: ObservableObject {
    static let shared = MempoolWebSocketService()
    
    let eventPublisher = PassthroughSubject<WebSocketEvent, Never>()
    
    @Published var isConnected = false
    @Published var lastBlockHeight: Int?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let wsURL = URL(string: "wss://mempool.space/api/v1/ws")!
    
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var reconnectTimer: Timer?
    private var trackedTxids: Set<String> = []
    private var trackedAddresses: Set<String> = []
    private var pingTimer: Timer?
    
    private init() {}
    
    // MARK: - Connection Management
    
    func connect() {
        guard webSocketTask == nil else { return }
        
        let task = session.webSocketTask(with: wsURL)
        self.webSocketTask = task
        task.resume()
        
        // Subscribe to blocks, mempool-blocks, stats, live-2h-chart
        let subscribeMsg = #"{"action":"want","data":["blocks","mempool-blocks","stats","live-2h-chart"]}"#
        task.send(.string(subscribeMsg)) { [weak self] error in
            if let error = error {
                print("[WS] Subscribe error: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.reconnectAttempts = 0
                    self?.eventPublisher.send(.connected)
                }
                // Re-track any txids and addresses
                self?.resubscribeTrackedItems()
            }
        }
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping timer to keep connection alive
        startPingTimer()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    // MARK: - Transaction Tracking
    
    func trackTransaction(_ txid: String) {
        trackedTxids.insert(txid)
        guard let task = webSocketTask else { return }
        
        let msg = #"{"track-tx":"\#(txid)"}"#
        task.send(.string(msg)) { error in
            if let error = error {
                print("[WS] Track tx error: \(error)")
            } else {
                print("[WS] Tracking tx: \(txid.prefix(12))...")
            }
        }
    }
    
    func untrackTransaction(_ txid: String) {
        trackedTxids.remove(txid)
    }
    
    // MARK: - Address Tracking
    
    func trackAddress(_ address: String) {
        trackedAddresses.insert(address)
        guard let task = webSocketTask else { return }
        
        let msg = #"{"track-address":"\#(address)"}"#
        task.send(.string(msg)) { error in
            if let error = error {
                print("[WS] Track address error: \(error)")
            } else {
                print("[WS] Tracking address: \(address.prefix(8))...")
            }
        }
    }
    
    func untrackAddress(_ address: String) {
        trackedAddresses.remove(address)
    }
    
    // MARK: - Private
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self?.receiveMessage()
                
            case .failure(let error):
                print("[WS] Receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.eventPublisher.send(.disconnected)
                }
                self?.webSocketTask = nil
                self?.scheduleReconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Handle new block event
                if let block = json["block"] as? [String: Any] {
                    let height = block["height"] as? Int ?? 0
                    let hash = block["id"] as? String ?? ""
                    let timestamp = block["timestamp"] as? Int ?? 0
                    let txCount = block["tx_count"] as? Int ?? 0
                    let size = block["size"] as? Int ?? 0
                    
                    let blockData = NewBlockData(
                        height: height,
                        hash: hash,
                        timestamp: timestamp,
                        txCount: txCount,
                        size: size
                    )
                    
                    DispatchQueue.main.async {
                        self.lastBlockHeight = height
                        self.eventPublisher.send(.newBlock(blockData))
                    }
                }
                
                // Handle transaction confirmation
                // The API sends {"txConfirmation": {"txid": "...", "block": {...}}}
                // when a tracked tx gets confirmed
                if let txConfirmation = json["txConfirmation"] as? [String: Any] {
                    let txid = txConfirmation["txid"] as? String
                    let blockInfo = txConfirmation["block"] as? [String: Any]
                    let blockHeight = blockInfo?["height"] as? Int
                    
                    if let txid = txid {
                        DispatchQueue.main.async {
                            self.eventPublisher.send(.transactionConfirmed(txid: txid, blockHeight: blockHeight))
                        }
                        trackedTxids.remove(txid)
                    }
                }
                
                // Handle address updates
                if let addressData = json["address-transactions"] as? [[String: Any]], !addressData.isEmpty {
                    // Extract the address if present, or just trigger refresh
                    // Unfortunately, the API doesn't always echo the address back easily
                    // So we might need to rely on the ViewModel refreshing all stats when *any* update happens
                    // or just publish a generic update. For now, publish for all tracked.
                    for address in trackedAddresses {
                        DispatchQueue.main.async {
                            self.eventPublisher.send(.addressUpdated(address: address))
                        }
                    }
                }
                
                // Handle projected blocks
                if let projected = json["mempool-blocks"] as? [[String: Any]] {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: projected)
                        let blocks = try JSONDecoder().decode([ProjectedBlock].self, from: data)
                        DispatchQueue.main.async {
                            self.eventPublisher.send(.projectedBlocks(blocks))
                        }
                    } catch {
                        print("[WS] Failed to decode projected blocks: \(error)")
                    }
                }
                
                // Handle mempool stats
                if let statsData = json["mempoolInfo"] as? [String: Any] {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: statsData)
                        let stats = try JSONDecoder().decode(MempoolStats.self, from: data)
                        DispatchQueue.main.async {
                            self.eventPublisher.send(.stats(stats))
                        }
                    } catch {
                        print("[WS] Failed to decode stats: \(error)")
                    }
                }
                
                // Handle hashrate (live-2h-chart)
                if let liveHashrate = json["live-2h-chart"] as? [String: Any],
                   let hashrateData = liveHashrate["hashrate"] as? [[String: Any]] {
                    
                    do {
                        // The format might be different than our Hasrate model, but typically looks the same if we decode properly
                        let data = try JSONSerialization.data(withJSONObject: hashrateData)
                        let rates = try JSONDecoder().decode([Hashrate].self, from: data)
                        DispatchQueue.main.async {
                            self.eventPublisher.send(.hashrate(rates))
                        }
                    } catch {
                        print("[WS] Failed to decode hashrate: \(error)")
                    }
                }
            }
        } catch {
            // Not all messages are JSON we care about
        }
    }
    
    private func resubscribeTrackedItems() {
        for txid in trackedTxids {
            guard let task = webSocketTask else { return }
            let msg = #"{"track-tx":"\#(txid)"}"#
            task.send(.string(msg)) { _ in }
        }
        for address in trackedAddresses {
            guard let task = webSocketTask else { return }
            let msg = #"{"track-address":"\#(address)"}"#
            task.send(.string(msg)) { _ in }
        }
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if let error = error {
                    print("[WS] Ping error: \(error)")
                }
            }
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[WS] Max reconnect attempts reached")
            return
        }
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        reconnectAttempts += 1
        
        print("[WS] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")
        
        DispatchQueue.main.async {
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect()
            }
        }
    }
}
