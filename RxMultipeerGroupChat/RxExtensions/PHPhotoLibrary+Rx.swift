//
//  PHPhotoLibrary+Rx.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/23/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License.
//

import Foundation
import Photos
import RxCocoa
import RxSwift

extension Reactive where Base: PHPhotoLibrary {
	static var requestAuthorization: Observable<PHAuthorizationStatus> {
		return Observable.create { observer in
			Base.requestAuthorization { status in
				observer.onNext(status)
				observer.onCompleted()
			}
			return Disposables.create()
		}
	}
}
