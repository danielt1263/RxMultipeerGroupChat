//
//  RxMCSessionDelegateProxy.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/21/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License.
//

import Foundation
import MultipeerConnectivity
import RxSwift
import RxCocoa

extension MCSession: HasDelegate {
	public typealias Delegate = MCSessionDelegate
}

class RxMCSessionDelegateProxy: DelegateProxy<MCSession, MCSessionDelegate>, DelegateProxyType, MCSessionDelegate {

	init(session: MCSession) {
		super.init(parentObject: session, delegateProxy: RxMCSessionDelegateProxy.self)
	}

	static func registerKnownImplementations() {
		self.register { RxMCSessionDelegateProxy(session: $0) }
	}

	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		subject.onNext(.peerDidChangeState(peerID: peerID, state: state))
	}

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		subject.onNext(.didReceiveDataFromPeer(data: data, peerID: peerID))
	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		subject.onNext(.didReceiveStream(stream: stream, streamName: streamName, peerID: peerID))
	}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		subject.onNext(.didStartReceivingResource(name: resourceName, peerID: peerID, progress: progress))
	}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
		subject.onNext(.didFinishReceivingResource(name: resourceName, peerID: peerID, localURL: localURL, error: error))
	}

	fileprivate let subject = PublishSubject<MCSessionAction>()
}

private enum MCSessionAction {
	case peerDidChangeState(peerID: MCPeerID, state: MCSessionState)
	case didReceiveDataFromPeer(data: Data, peerID: MCPeerID)
	case didReceiveStream(stream: InputStream, streamName: String, peerID: MCPeerID)
	case didStartReceivingResource(name: String, peerID: MCPeerID, progress: Progress)
	case didFinishReceivingResource(name: String, peerID: MCPeerID, localURL: URL?, error: Error?)
}

extension Reactive where Base: MCSession {
	func send(_ data: Data, toPeers peerIDs: [MCPeerID], with mode: MCSessionSendDataMode) -> Observable<Void> {
		return Observable.create { observer in
			do {
				try self.base.send(data, toPeers: peerIDs, with: mode)
				observer.onNext(())
				observer.onCompleted()
			}
			catch {
				observer.onError(error)
			}
			return Disposables.create()
		}
	}
}
extension Reactive where Base: MCSession {
	public var delegate: DelegateProxy<MCSession, MCSessionDelegate> {
		return RxMCSessionDelegateProxy.proxy(for: self.base)
	}

	func peerDidChangeState() -> Observable<(peerID: MCPeerID, state: MCSessionState)> {
		let delegate = RxMCSessionDelegateProxy.proxy(for: base)
		return delegate.subject.asObserver()
			.map { (action) -> (peerID: MCPeerID, state: MCSessionState)? in
				guard case let .peerDidChangeState(peerID, state) = action else { return nil }
				return (peerID, state)
			}
			.filter { $0 != nil }
			.map { $0! }
	}

	func didReceiveDataFromPeer() -> Observable<(data: Data, peerID: MCPeerID)> {
		let delegate = RxMCSessionDelegateProxy.proxy(for: base)
		return delegate.subject.asObserver()
			.map { (action) -> (data: Data, peerID: MCPeerID)? in
				guard case let .didReceiveDataFromPeer(data, peerID) = action else { return nil }
				return (data, peerID)
			}
			.filter { $0 != nil }
			.map { $0! }
	}

	func didReceiveStream() -> Observable<(stream: InputStream, streamName: String, peerID: MCPeerID)> {
		let delegate = RxMCSessionDelegateProxy.proxy(for: base)
		return delegate.subject.asObserver()
			.map { (action) -> (stream: InputStream, streamName: String, peerID: MCPeerID)? in
				guard case let .didReceiveStream(stream, streamName, peerID) = action else { return nil }
				return (stream, streamName, peerID)
			}
			.filter { $0 != nil }
			.map { $0! }
	}

	func didStartReceivingResource() -> Observable<(name: String, peerID: MCPeerID, progress: Progress)> {
		let delegate = RxMCSessionDelegateProxy.proxy(for: base)
		return delegate.subject.asObserver()
			.map { (action) -> (name: String, peerID: MCPeerID, progress: Progress)? in
				guard case let .didStartReceivingResource(name, peerID, progress) = action else { return nil }
				return (name, peerID, progress)
			}
			.filter { $0 != nil }
			.map { $0! }
	}

	func didFinishReceivingResource() -> Observable<(name: String, peerID: MCPeerID, localURL: URL?, error: Error?)> {
		let delegate = RxMCSessionDelegateProxy.proxy(for: base)
		return delegate.subject.asObserver()
			.map { (action) -> (name: String, peerID: MCPeerID, localURL: URL?, error: Error?)? in
				guard case let .didFinishReceivingResource(name, peerID, localURL, error) = action else { return nil }
				return (name, peerID, localURL, error)
			}
			.filter { $0 != nil }
			.map { $0! }
	}
}
