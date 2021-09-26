//
//  ProgressObserver.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import RxSwift

extension Progress {
	enum Error: Swift.Error { case cancelled }
	var changed: Observable<Progress> {
		let cancelled = rx.observe(Bool.self, kProgressCancelledKeyPath, options: .new)
		let completedUnitCount = rx.observe(Int64.self, kProgressCompletedUnitCountKeyPath, options: .new)
		return completedUnitCount
			.take(until: { $0 == self.totalUnitCount }, behavior:  .exclusive)
			.take(until: cancelled.map { _ in throw Error.cancelled })
			.map { _ in self }
	}
}
private let kProgressCancelledKeyPath = "cancelled"
private let kProgressCompletedUnitCountKeyPath = "completedUnitCount"
