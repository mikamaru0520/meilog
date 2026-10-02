import Foundation
import Network
import MeilogCore

/// Network.framework to manage card exchange connections
@MainActor
final class ExchangeNetworkManager: @unchecked Sendable {
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private var discoveredEndpoints: [String: NWEndpoint] = [:]
    
    /// Callback for discovered peers
    var onPeerDiscovered: ((String, String, Int) -> Void)?
    
    /// Callback for lost peers
    var onPeerLost: ((String) -> Void)?
    
    /// Callback for received invitations
    var onInvitationReceived: ((String, String, Int) -> Void)?
    
    /// Callback for received data
    var onDataReceived: ((CardEnvelope) -> Void)?
    
    /// Callback for connection failures
    var onConnectionFailed: ((Error) -> Void)?
    
    /// Callback for connection success
    var onConnectionEstablished: (() -> Void)?
    
    private let serviceType = "_meilog._tcp"
    private let queue = DispatchQueue(label: "com.example.meilog.network", qos: .userInitiated)
    
    init() {}
    
    // MARK: - Advertising
    
    /// Start advertising this device
    func startAdvertising(name: String, paletteID: Int) throws {
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        parameters.includePeerToPeer = true
        
        // Create TXT record
        var txtRecord = NWTXTRecord()
        txtRecord["name"] = name
        txtRecord["paletteID"] = "\(paletteID)"
        
        // Create listener with service
        let listener = try NWListener(using: parameters, on: .any)
        listener.service = NWListener.Service(name: name, type: serviceType, txtRecord: txtRecord)
        
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("Listener ready")
                case .failed(let error):
                    print("Listener failed: \(error)")
                    self?.onConnectionFailed?(error)
                case .cancelled:
                    print("Listener cancelled")
                default:
                    break
                }
            }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleIncomingConnection(connection)
            }
        }
        
        listener.start(queue: queue)
        self.listener = listener
    }
    
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
    }
    
    // MARK: - Browsing
    
    /// Start browsing for nearby devices
    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        
        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Browser ready")
            case .failed(let error):
                print("Browser failed: \(error)")
                Task { @MainActor in
                    self.onConnectionFailed?(error)
                }
            case .cancelled:
                print("Browser cancelled")
            default:
                break
            }
        }
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                for change in changes {
                    switch change {
                    case .added(let result):
                        self?.handleDiscoveredPeer(result)
                    case .removed(let result):
                        if case .service(let name, _, _, _) = result.endpoint {
                            self?.discoveredEndpoints.removeValue(forKey: name)
                            self?.onPeerLost?(name)
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        browser.start(queue: queue)
        self.browser = browser
    }
    
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }
    
    // MARK: - Connection
    
    /// Send invitation to a peer
    func sendInvitation(to peerID: String) {
        guard let endpoint = discoveredEndpoints[peerID] else {
            onConnectionFailed?(NetworkError.endpointNotFound)
            return
        }
        
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        parameters.includePeerToPeer = true
        
        let connection = NWConnection(to: endpoint, using: parameters)
        connections[peerID] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.onConnectionEstablished?()
                case .failed(let error):
                    self?.connections.removeValue(forKey: peerID)
                    self?.onConnectionFailed?(error)
                case .cancelled:
                    self?.connections.removeValue(forKey: peerID)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    /// Send card data to a peer
    func sendData(_ envelope: CardEnvelope, to peerID: String) throws {
        guard let connection = connections[peerID] else {
            throw NetworkError.connectionNotFound
        }
        
        let data = try CardPayload.encode(envelope)
        
        // Send length prefix (4 bytes) followed by data
        var lengthPrefix = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &lengthPrefix, count: 4)
        
        connection.send(content: lengthData + data, completion: .contentProcessed { error in
            if let error = error {
                print("Send failed: \(error)")
                Task { @MainActor in
                    self.onConnectionFailed?(error)
                }
            }
        })
    }
    
    // MARK: - Private Helpers
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.receiveData(from: connection)
                case .failed(let error):
                    print("Incoming connection failed: \(error)")
                    self?.onConnectionFailed?(error)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveData(from connection: NWConnection) {
        // First receive 4-byte length prefix
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, data.count == 4 else {
                if let error = error {
                    print("Receive length failed: \(error)")
                }
                return
            }
            
            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Sanity check: reject unreasonably large payloads
            guard length > 0 && length < 10_000_000 else {
                print("Invalid payload length: \(length)")
                return
            }
            
            // Now receive the actual data
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { data, _, isComplete, error in
                Task { @MainActor in
                    guard let data = data else {
                        if let error = error {
                            print("Receive data failed: \(error)")
                            self.onConnectionFailed?(error)
                        }
                        return
                    }
                    
                    do {
                        let envelope = try CardPayload.decode(data)
                        self.onDataReceived?(envelope)
                    } catch {
                        print("Decode failed: \(error)")
                        self.onConnectionFailed?(error)
                    }
                }
            }
        }
    }
    
    private func handleDiscoveredPeer(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else {
            return
        }
        
        // Store the endpoint for later connection
        discoveredEndpoints[name] = result.endpoint
        
        // Extract metadata from TXT record
        guard case .bonjour(let txtRecord) = result.metadata else {
            return
        }
        
        var peerName = name
        var paletteID = 0

        if let nameString = txtRecord["name"] {
            peerName = nameString
        }

        if let paletteIDString = txtRecord["paletteID"],
           let paletteIDInt = Int(paletteIDString) {
            paletteID = paletteIDInt
        }
        
        onPeerDiscovered?(name, peerName, paletteID)
    }
}

enum NetworkError: Error {
    case connectionNotFound
    case endpointNotFound
    case encodingFailed
    case decodingFailed
}
