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

func dismissViewController(_ viewController: UIViewController, animated: Bool) {
	if viewController.isBeingDismissed || viewController.isBeingPresented {
		DispatchQueue.main.async {
			dismissViewController(viewController, animated: animated)
		}

		return
	}

	if viewController.presentingViewController != nil {
		viewController.dismiss(animated: animated, completion: nil)
	}
}

extension Reactive where Base: MCBrowserViewController {
	static func createWithParent(_ parent: UIViewController?, animated: Bool = true, serviceType: String, session: MCSession, configureImagePicker: @escaping (MCBrowserViewController) throws -> () = { _ in }) -> Observable<MCBrowserViewController> {
		return Observable.create { [weak parent] observer in
			let mcBrowser = MCBrowserViewController.init(serviceType: serviceType, session: session)
			let dismissDisposable = mcBrowser.rx.wasCancelled()
				.subscribe(onNext: { [weak mcBrowser] _ in
					guard let mcBrowser = mcBrowser else { return }
					dismissViewController(mcBrowser, animated: animated)
				})

			do {
				try configureImagePicker(mcBrowser)
			}
			catch let error {
				observer.on(.error(error))
				return Disposables.create()
			}

			guard let parent = parent else {
				observer.on(.completed)
				return Disposables.create()
			}

			parent.present(mcBrowser, animated: animated, completion: nil)
			observer.on(.next(mcBrowser))

			return Disposables.create(dismissDisposable, Disposables.create {
				dismissViewController(mcBrowser, animated: animated)
			})
		}
	}
}
