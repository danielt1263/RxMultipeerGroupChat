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
	let received: Observable<Transcript>
	var update: Observable<Transcript> {
		return _update.asObservable()
	}

	private let _update = PublishSubject<Transcript>()
	private let disposeBag = DisposeBag()
	private let advertiserAssistant: MCAdvertiserAssistant

	init(displayName: String, serviceType: String) {
		let peerID = MCPeerID(displayName: displayName)
		session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		advertiserAssistant = MCAdvertiserAssistant(serviceType: serviceType, discoveryInfo: nil, session: session)
		advertiserAssistant.start()
		let peerDidChangeState = session.rx.peerDidChangeState()
			.do(onNext: { print("Peer [\($0.peerID.displayName)] changed state to \($0.state.display)") })
			.makeTranscript()

		let didReceiveDataFromPeer = session.rx.didReceiveDataFromPeer()
			.makeTranscript()

		let didStartReceivingResource = session.rx.didStartReceivingResource()
			.do(onNext: { print("Start receiving resource [\($0.name)] from peer \($0.peerID.displayName) with progress [\($0.progress)]") })
			.map { Transcript(peerID: $0.peerID, imageName: $0.name, progress: $0.progress, direction: .receive) }

		received = Observable.merge(peerDidChangeState, didReceiveDataFromPeer, didStartReceivingResource)

		super.init()

		session.rx.didFinishReceivingResource()
			.bind(onNext: { [weak self] resourceName, peerID, localURL, error in
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
						self?._update.onNext(transcript)
					}
					catch {
						print("Error copying resource to documents directory")
					}
				}
			})
			.disposed(by: disposeBag)
		session.rx.didReceiveStream()
			.bind(onNext: { stream, streamName, peerID in
				print("Received data over stream with name \(streamName) from peer \(peerID.displayName)")
			})
			.disposed(by: disposeBag)
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

extension ObservableType where E == (peerID: MCPeerID, state: MCSessionState) {
	func makeTranscript() -> Observable<Transcript> {
		return map { (peerID: $0.peerID, adminMessage: "'\($0.peerID.displayName)' is \($0.state.display)")}
			.map { Transcript(peerID: $0.peerID, message: $0.adminMessage, direction: .local) }
	}
}

extension ObservableType where E == (data: Data, peerID: MCPeerID) {
	func makeTranscript() -> Observable<Transcript> {
		return map { (peerID: $1, message: String(data: $0, encoding: .utf8) ?? "unparsable data") }
			.map { Transcript(peerID: $0.peerID, message: $0.message, direction: .receive) }
	}
}

extension MCSessionState {
	var display: String {
		switch self {
		case .notConnected:
			return "Not Connected"
		case .connecting:
			return "Connecting"
		case .connected:
			return "Connected"
		}
	}
}
