//
//  ProgressObserver.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit

class ProgressObserver: NSObject {
	let name: String
	let progress: Progress
	weak var delegate: ProgressObserverDelegate?

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
			delegate?.observerDidCancel(self)
		}
		else if keyPath == kProgressCompletedUnitCountKeyPath {
			delegate?.observerDidChange(self)
			if progress.completedUnitCount == progress.totalUnitCount {
				delegate?.observerDidComplete(self)
			}
		}
	}
}

protocol ProgressObserverDelegate: class {
	func observerDidChange(_ observer: ProgressObserver)
	func observerDidCancel(_ observer: ProgressObserver)
	func observerDidComplete(_ observer: ProgressObserver)
}

private let kProgressCancelledKeyPath = "cancelled"
private let kProgressCompletedUnitCountKeyPath = "completedUnitCount"
