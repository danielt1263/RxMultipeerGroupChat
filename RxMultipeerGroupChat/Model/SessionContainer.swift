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

		let copiedResourceFromPeer = session.rx.didFinishReceivingResource()
			.filter { $0.error == nil }.map { (name: $0.name, peerID: $0.peerID, localURL: $0.localURL!) }
			.flatMap { Observable.zip(Observable.just($0.peerID), copyItem(resourceName: $0.name, localURL: $0.localURL), resultSelector: { (peerID: $0, imageUrl: $1) }).materialize() }

		copiedResourceFromPeer
			.filter { $0.error == nil }.dematerialize()
			.map { Transcript(peerID: $0.peerID, imageUrl: $0.imageUrl, direction: .receive) }
			.bind(to: _update)
			.disposed(by: disposeBag)

		copiedResourceFromPeer
			.filter { $0.error != nil }
			.bind(onNext: { _ in
				print("Error copying resource to documents directory")
			})
			.disposed(by: disposeBag)

		session.rx.didFinishReceivingResource()
			.filter { $0.error != nil }.map { (error: $0.error!, peerID: $0.peerID) }
			.bind(onNext: { error, peerID in
				print("Error [\(error.localizedDescription)] receiving resource from peer \(peerID.displayName)")
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

	func send(message: String) -> Observable<Transcript?> {
		let messageData = message.data(using: .utf8)!
		return Observable.just(session)
			.flatMap { session in session.rx.send(messageData, toPeers: session.connectedPeers, with: .reliable).map { session } }
			.map { Transcript(peerID: $0.myPeerID, message: message, direction: .send) }
			.catchErrorJustReturn(nil)
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

func copyItem(resourceName: String, localURL: URL) -> Observable<URL> {
	return Observable.create { observer in
		let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
		let copyPath = "\(paths[0])/\(resourceName)"
		do {
			try FileManager.default.copyItem(atPath: localURL.path, toPath: copyPath)
			observer.onNext(URL(fileURLWithPath: copyPath))
			observer.onCompleted()
		}
		catch {
			observer.onError(error)
		}
		return Disposables.create()
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
