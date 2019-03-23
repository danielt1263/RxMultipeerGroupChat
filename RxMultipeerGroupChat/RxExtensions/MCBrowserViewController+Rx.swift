//
//  RxMCBrowserViewControllerDelegateProxy.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/22/19.
//  Copyright © 2019 Daniel Tartaglia. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import RxSwift
import RxCocoa

extension MCBrowserViewController: HasDelegate {
	public typealias Delegate = MCBrowserViewControllerDelegate
}

class RxMCBrowserViewControllerDelegateProxy: DelegateProxy<MCBrowserViewController, MCBrowserViewControllerDelegate>, DelegateProxyType, MCBrowserViewControllerDelegate {
	init(controller: MCBrowserViewController) {
		super.init(parentObject: controller, delegateProxy: RxMCBrowserViewControllerDelegateProxy.self)
	}

	static func registerKnownImplementations() {
		self.register { RxMCBrowserViewControllerDelegateProxy(controller: $0) }
	}

	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		didFinish.onNext(())
	}

	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		wasCancelled.onNext(())
	}

	func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
		return shouldPresent(peerID, info ?? [:])
	}

	fileprivate let didFinish = PublishSubject<Void>()
	fileprivate let wasCancelled = PublishSubject<Void>()
	fileprivate var shouldPresent: (MCPeerID, [String: String]) -> Bool = { _, _ in true }
}

extension Reactive where Base: MCBrowserViewController {
	public var delegate: DelegateProxy<MCBrowserViewController, MCBrowserViewControllerDelegate> {
		return RxMCBrowserViewControllerDelegateProxy.proxy(for: base)
	}

	func didFinish() -> Observable<Void> {
		let delegate = RxMCBrowserViewControllerDelegateProxy.proxy(for: base)
		return delegate.didFinish.asObservable()
	}

	func wasCancelled() -> Observable<Void> {
		let delegate = RxMCBrowserViewControllerDelegateProxy.proxy(for: base)
		return delegate.wasCancelled.asObservable()
	}

	var shouldPresentNearbyPeer: (MCPeerID, [String: String]) -> Bool {
		get {
			let delegate = RxMCBrowserViewControllerDelegateProxy.proxy(for: base)
			return delegate.shouldPresent
		}
		set(value) {
			let delegate = RxMCBrowserViewControllerDelegateProxy.proxy(for: base)
			delegate.shouldPresent = value
		}
	}
}
