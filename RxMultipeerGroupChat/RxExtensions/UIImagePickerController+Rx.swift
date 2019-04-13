//
//  UIImagePickerController+Rx.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/23/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License.
//


import RxSwift
import RxCocoa
import UIKit

extension UIImagePickerController {
	public typealias Delegate = UIImagePickerControllerDelegate & UINavigationControllerDelegate
}

class RxUIImagePickerControllerDelegateProxy: DelegateProxy<UIImagePickerController, UIImagePickerControllerDelegate & UINavigationControllerDelegate>, DelegateProxyType, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
	init(controller: UIImagePickerController) {
		super.init(parentObject: controller, delegateProxy: RxUIImagePickerControllerDelegateProxy.self)
	}

	static func registerKnownImplementations() {
		self.register { RxUIImagePickerControllerDelegateProxy(controller: $0) }
	}

	static func currentDelegate(for object: UIImagePickerController) -> (UIImagePickerControllerDelegate & UINavigationControllerDelegate)? {
		return object.delegate
	}

	static func setCurrentDelegate(_ delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?, to object: UIImagePickerController) {
		object.delegate = delegate
	}
}

extension Reactive where Base: UIImagePickerController {

	public var didFinishPickingMediaWithInfo: Observable<[UIImagePickerController.InfoKey: Any]> {
		let delegate = RxUIImagePickerControllerDelegateProxy.proxy(for: base)
		return delegate
			.methodInvoked(#selector(UIImagePickerControllerDelegate.imagePickerController(_:didFinishPickingMediaWithInfo:)))
			.map({ (a) in
				return try castOrThrow(Dictionary<UIImagePickerController.InfoKey, Any>.self, a[1])
			})
	}

	public var didCancel: Observable<()> {
		let delegate = RxUIImagePickerControllerDelegateProxy.proxy(for: base)
		return delegate
			.methodInvoked(#selector(UIImagePickerControllerDelegate.imagePickerControllerDidCancel(_:)))
			.map {_ in () }
	}
}

fileprivate func castOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
	guard let returnValue = object as? T else {
		throw RxCocoaError.castingError(object: object, targetType: resultType)
	}

	return returnValue
}

extension Reactive where Base: UIImagePickerController {
	static func createWithParent(_ parent: UIViewController?, animated: Bool = true, configureImagePicker: @escaping (UIImagePickerController) throws -> Void = { x in }) -> Observable<UIImagePickerController> {
		return Observable.create { [weak parent] observer in
			let imagePicker = UIImagePickerController()
			let dismissDisposable = imagePicker.rx
				.didCancel
				.subscribe(onNext: { [weak imagePicker] _ in
					guard let imagePicker = imagePicker else {
						return
					}
					dismissViewController(imagePicker, animated: animated)
				})

			do {
				try configureImagePicker(imagePicker)
			}
			catch let error {
				observer.on(.error(error))
				return Disposables.create()
			}

			guard let parent = parent else {
				observer.on(.completed)
				return Disposables.create()
			}

			parent.present(imagePicker, animated: animated, completion: nil)
			observer.on(.next(imagePicker))

			return Disposables.create(dismissDisposable, Disposables.create {
				dismissViewController(imagePicker, animated: animated)
			})
		}
	}
}
