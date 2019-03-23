//
//  ProgressObserver.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import RxSwift

enum ProgressObserverError: Error {
	case canceled
}

class ProgressObserver: NSObject {
	let name: String
	let progress: Progress
	var changed: Observable<Progress> {
		return _changed.asObservable()
	}
	private let _changed = PublishSubject<Progress>()
	private let disposeBag = DisposeBag()

	init(name: String, progress: Progress) {
		self.name = name
		self.progress = progress
		super.init()
		progress.rx.observe(Bool.self, kProgressCancelledKeyPath, options: .new)
			.bind(onNext: { [weak self] _ in
				self?._changed.onError(ProgressObserverError.canceled)
			})
			.disposed(by: disposeBag)

		progress.rx.observe(Int64.self, kProgressCompletedUnitCountKeyPath, options: .new)
			.bind(onNext: { [weak self] _ in
				self?._changed.onNext(progress)
				if progress.completedUnitCount == progress.totalUnitCount {
					self?._changed.onCompleted()
				}
			})
			.disposed(by: disposeBag)
	}
}

private let kProgressCancelledKeyPath = "cancelled"
private let kProgressCompletedUnitCountKeyPath = "completedUnitCount"
