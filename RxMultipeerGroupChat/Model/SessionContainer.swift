//
//  SessionContainer.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import MultipeerConnectivity
import RxSwift

class SessionContainer: NSObject {
	let session: MCSession
	var received: Observable<Transcript> {
		return _received.asObservable()
	}
	var update: Observable<Transcript> {
		return _update.asObservable()
	}
	private let _received = PublishSubject<Transcript>()
	private let _update = PublishSubject<Transcript>()
	private let advertiserAssistant: MCAdvertiserAssistant

	init(displayName: String, serviceType: String) {
		let peerID = MCPeerID(displayName: displayName)
		session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		advertiserAssistant = MCAdvertiserAssistant(serviceType: serviceType, discoveryInfo: nil, session: session)
		super.init()
		session.delegate = self
		advertiserAssistant.start()
	}

	deinit {
		advertiserAssistant.stop()
		session.disconnect()
	}

	func send(message: String) -> Transcript? {
		do {
			let messageData = message.data(using: .utf8)!
			try session.send(messageData, toPeers: session.connectedPeers, with: .reliable)
			return Transcript(peerID: session.myPeerID, message: message, direction: .send)
		}
		catch {
			print("Error sending message to peers [\(error)]")
			return nil
		}
	}

	func send(imageUrl: URL) -> Transcript {
		var progress: Progress?
		for peerID in session.connectedPeers {
			progress = session.sendResource(at: imageUrl, withName: imageUrl.lastPathComponent, toPeer: peerID) { error in
				if let error = error {
					print("Send resource to peer [\(peerID.displayName)] completed with Error [\(error)]")
				}
				else {
					let transcript = Transcript(peerID: self.session.myPeerID, imageUrl: imageUrl, direction: .send)
					self._update.onNext(transcript)
				}
			}
		}
		let transcript = Transcript(peerID: session.myPeerID, imageName: imageUrl.lastPathComponent, progress: progress, direction: .send)
		return transcript
	}
}

func string(for state: MCSessionState) -> String {
	switch state {
	case .notConnected:
		return "Not Connected"
	case .connecting:
		return "Connecting"
	case .connected:
		return "Connected"
	}
}

extension SessionContainer: MCSessionDelegate {
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		print("Peer [\(peerID.displayName)] changed state to \(string(for: state))")

		let adminMessage = "'\(peerID.displayName)' is \(string(for: state))"
		let transcript = Transcript(peerID: peerID, message: adminMessage, direction: .local)

		_received.onNext(transcript)
	}

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		let receivedMessage = String(data: data, encoding: .utf8) ?? "unparsable data"
		let transcript = Transcript(peerID: peerID, message: receivedMessage, direction: .receive)

		_received.onNext(transcript)
	}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		print("Start receiving resource [\(resourceName)] from peer \(peerID.displayName) with progress [\(progress)]")
		let transcript = Transcript(peerID: peerID, imageName: resourceName, progress: progress, direction: .receive)
		_received.onNext(transcript)
	}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
		if let error = error {
			print("Error [\(error.localizedDescription)] receiving resource from peer \(peerID.displayName)")
		}
		else {
			do {
				let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
				let copyPath = "\(paths[0])/\(resourceName)"
				try FileManager.default.copyItem(atPath: localURL!.path, toPath: copyPath)
				let imageUrl = URL.init(fileURLWithPath: copyPath)
				let transcript = Transcript(peerID: peerID, imageUrl: imageUrl, direction: .receive)
				_update.onNext(transcript)
			}
			catch {
				print("Error copying resource to documents directory")
			}
		}
	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		print("Received data over stream with name \(streamName) from peer \(peerID.displayName)")
	}
}
