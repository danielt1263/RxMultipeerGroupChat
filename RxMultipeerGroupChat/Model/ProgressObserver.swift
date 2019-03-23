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

	init(name: String, progress: Progress) {
		self.name = name
		self.progress = progress
		super.init()
		progress.addObserver(self, forKeyPath: kProgressCancelledKeyPath, options: .new, context: nil)
		progress.addObserver(self, forKeyPath: kProgressCompletedUnitCountKeyPath, options: .new, context: nil)
	}

	deinit {
		progress.removeObserver(self, forKeyPath: kProgressCancelledKeyPath)
		progress.removeObserver(self, forKeyPath: kProgressCompletedUnitCountKeyPath)
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		let progress = object as! Progress

		if keyPath == kProgressCancelledKeyPath {
			_changed.onError(ProgressObserverError.canceled)
		}
		else if keyPath == kProgressCompletedUnitCountKeyPath {
			_changed.onNext(progress)
			if progress.completedUnitCount == progress.totalUnitCount {
				_changed.onCompleted()
			}
		}
	}
}

private let kProgressCancelledKeyPath = "cancelled"
private let kProgressCompletedUnitCountKeyPath = "completedUnitCount"
