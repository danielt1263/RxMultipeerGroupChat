//
//  Transcript.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import Foundation
import MultipeerConnectivity

enum TranscriptDirection {
	case send
	case receive
	case local
}

struct Transcript {
	let direction: TranscriptDirection
	let peerID: MCPeerID
	let message: String
	let imageName: String
	let imageUrl: URL?
	let progress: Progress?
}

extension Transcript {
	init(peerID: MCPeerID, message: String, direction: TranscriptDirection) {
		self.init(direction: direction, peerID: peerID, message: message, imageName: "", imageUrl: nil, progress: nil)

	}

	init(peerID: MCPeerID, imageUrl: URL, direction: TranscriptDirection) {
		self.init(direction: direction, peerID: peerID, message: "", imageName: imageUrl.lastPathComponent, imageUrl: imageUrl, progress: nil)
	}

	init(peerID: MCPeerID, imageName: String, progress: Progress?, direction: TranscriptDirection) {
		self.init(direction: direction, peerID: peerID, message: "", imageName: imageName, imageUrl: nil, progress: progress)
	}
}
