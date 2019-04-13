//
//  UIAlertController+Rx.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 4/12/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License.
//

import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UIAlertController {
	static func createWithParent<A: CustomStringConvertible>(_ parent: UIViewController?, title: String?, message: String?, actions: [A], style: UIAlertController.Style, sourceView: UIView?) -> Observable<A> {
		return Observable.create { observer in
			let alert = UIAlertController(title: title, message: message, preferredStyle: style)
			let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in observer.onCompleted() })

			let actions = actions.enumerated().map { offset, element in
				UIAlertAction(title: element.description, style: .default, handler: { _ in
					observer.on(.next(element))
					observer.on(.completed)
				})
			}

			for action in actions + [cancelAction] {
				alert.addAction(action)
			}

			if let popoverPresentationController = alert.popoverPresentationController {
				popoverPresentationController.sourceView = sourceView
				popoverPresentationController.sourceRect = sourceView?.bounds ?? CGRect.zero
			}
			parent?.present(alert, animated: true, completion: nil)
			return Disposables.create {
				dismissViewController(alert, animated: true)
			}
		}
	}
}
