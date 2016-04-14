//
//  StompFrame.swift
//  StompClient
//
//  Created by ShengHua Wu on 4/13/16.
//  Copyright © 2016 shenghuawu. All rights reserved.
//

import Foundation

// MARK: - Commands
enum StompCommand: String {
    
    // MARK: - Cases
    case Connect = "CONNECT"
    case Disconnect = "DISCONNECT"
    case Subscribe = "SUBSCRIBE"
    case Unsubscribe = "UNSUBSCRIBE"
    
    case Connected = "CONNECTED"
    case Message = "MESSAGE"
    case Error = "ERROR"
    
}

// MARK: - Headers
enum StompHeader: Hashable {
    
    // MARK: - Cases
    case AcceptVersion(version: String)
    case HeartBeat(value: String)
    case Destination(path: String)
    case DestinationId(id: String)
    case Custom(key: String, value: String)
    
    case Version(version: String)
    case Subscription(subId: String)
    case MessageId(id: String)
    case ContentLength(length: String)
    case Message(message: String)
    
    // MARK: - Public Properties
    var key: String {
        switch self {
        case .AcceptVersion:
            return "accept-version"
        case .HeartBeat:
            return "heart-beat"
        case .Destination:
            return "destination"
        case .DestinationId:
            return "id"
        case .Custom(let key, _):
            return key
        case .Version:
            return "version"
        case .Subscription:
            return "subscription"
        case .MessageId:
            return "message-id"
        case .ContentLength:
            return "content-length"
        case .Message:
            return "message"
        }
    }
    
    var value: String {
        switch self {
        case .AcceptVersion(let version):
            return version
        case .HeartBeat(let value):
            return value
        case .Destination(let path):
            return path
        case .DestinationId(let id):
            return id
        case .Custom(_, let value):
            return value
        case .Version(let version):
            return version
        case .Subscription(let subId):
            return subId
        case .MessageId(let id):
            return id
        case .ContentLength(let length):
            return length
        case .Message(let body):
            return body
        }
    }
    
    var isMessage: Bool {
        switch self {
        case .Message:
            return true
        default:
            return false
        }
    }
    
    var hashValue: Int {
        return key.hashValue
    }
    
    // MARK: - Public Methods
    static func generateHeader(key: String, value: String) -> StompHeader? {
        switch key {
        case "version":
            return .Version(version: value)
        case "subscription":
            return .Subscription(subId: value)
        case "message-id":
            return .MessageId(id: value)
        case "content-length":
            return .ContentLength(length: value)
        case "message":
            return .Message(message: value)
        case "destination":
            return .Destination(path: value)
        case "heart-beat":
            return .HeartBeat(value: value)
        default:
            return nil
        }
    }
    
}

// MARK: - Equatable for Stomp Header
func ==(lhs: StompHeader, rhs: StompHeader) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

// MARK: - Response Types
enum StompResponseType: String {
    
    // MARK: -  Cases
    case Open = "o"
    case HeartBeat = "h"
    case Array = "a"
    case Message = "m"
    case Close = "c"
    
}

struct StompFrame: CustomStringConvertible {
    
    // MARK: - Public Properties
    var description: String {
        var string = command.rawValue + lineFeed
        for header in headers {
            string += header.key + ":" + header.value + lineFeed
        }
        string += lineFeed + nullChar
        return string
    }
    
    var message: String {
        let filteredHeaders = headers.filter { header -> Bool in
            return header.isMessage
        }
        
        if filteredHeaders.isEmpty {
            return ""
        } else {
            return filteredHeaders.first!.value
        }
    }
    
    // MARK: - Private Properties
    private let lineFeed = "\u{0A}"
    private let nullChar = "\u{00}"
    private(set) var type: StompResponseType?
    private(set) var command: StompCommand
    private(set) var headers: Set<StompHeader>
    private(set) var body: String?
    
    // MARK: - Designated Initializer
    init(type: StompResponseType? = nil, command: StompCommand, headers: Set<StompHeader> = [], body: String? = nil) {
        self.type = type
        self.command = command
        self.headers = headers
        self.body = body
    }
    
    // MARK: - Public Methods
    static func generateFrame(text: String) -> StompFrame {
        let type = StompResponseType(rawValue: String(text.characters.first!))!
        do {
            let (command, headers, body) = try String(text.characters.dropFirst()).parseJSONText()
            return StompFrame(type: type, command: command, headers: headers, body: body)
        } catch let error as NSError {
            return StompFrame(type: type, command: .Error, headers: [.Message(message: error.localizedDescription)])
        }
    }
    
}

// MARK: - Extensions
extension String {
    
    func parseJSONText() throws -> (StompCommand, Set<StompHeader>, String)  {
        let data = dataUsingEncoding(NSUTF8StringEncoding)!
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as! [String]
            let components = json.first!.componentsSeparatedByString("\n")
            let command = StompCommand(rawValue: components.first!)!
            
            var headers: Set<StompHeader> = []
            var body = ""
            var isBody = false
            for index in 1 ..< components.count {
                let component = components[index]
                if isBody {
                    body += component
                    if body.hasSuffix("\0") {
                        body = body.stringByReplacingOccurrencesOfString("\0", withString: "")
                    }
                } else {
                    if component == "" {
                        isBody = true
                    } else {
                        let parts = component.componentsSeparatedByString(":")
                        if let header = StompHeader.generateHeader(parts.first!, value: parts.last!) {
                            headers.insert(header)
                        }
                    }
                }
            }
            return (command, headers, body)
        } catch let error as NSError {
            throw error
        }
    }
    
}