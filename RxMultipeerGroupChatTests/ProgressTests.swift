//
//  RxMultipeerGroupChatTests.swift
//  RxMultipeerGroupChatTests
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import XCTest
import RxSwift
import RxTest
@testable import RxMultipeerGroupChat

class ProgressTests: XCTestCase {

	func testProgressCompleted() {
		let scheduler = TestScheduler(initialClock: 0)
		let result = scheduler.createObserver(Int64.self)
		let progress = Progress(totalUnitCount: 3)

		_ = scheduler.createHotObservable([.next(10, 1), .next(20, 2), .next(30, 3)])
			.bind(onNext: {
				progress.completedUnitCount = $0
			})
		_ = progress.changed
			.map { $0.completedUnitCount }
			.subscribe(result)
		scheduler.start()

		XCTAssertEqual(result.events, [.next(10, 1), .next(20, 2), .completed(30)])
	}

	func testProgressCancelled() {
		let scheduler = TestScheduler(initialClock: 0)
		let result = scheduler.createObserver(Int64.self)
		let progress = Progress(totalUnitCount: 3)

		_ = scheduler.createHotObservable([.next(15, true)])
			.bind(onNext: { _ in
				progress.cancel()
			})

		_ = scheduler.createHotObservable([.next(10, 1), .next(20, 2), .next(30, 3)])
			.bind(onNext: {
				progress.completedUnitCount = $0
			})
		_ = progress.changed
			.map { $0.completedUnitCount }
			.subscribe(result)
		scheduler.start()

		XCTAssertEqual(result.events, [.next(10, 1), .error(15, Progress.Error.cancelled)])
	}
}
