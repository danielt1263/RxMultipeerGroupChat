//
//  SettingsViewControllerTests.swift
//  RxMultipeerGroupChatTests
//
//  Created by Daniel Tartaglia on 3/27/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License.
//

import XCTest
import RxSwift
import RxTest
@testable import RxMultipeerGroupChat

class SettingsViewControllerTests: XCTestCase {

	func testDefault() {
		let scheduler = TestScheduler(initialClock: 0)
		let displayName = scheduler.createHotObservable([Recorded<Event<String?>>]())
		let serviceType = scheduler.createHotObservable([Recorded<Event<String?>>]())
		let doneButton = scheduler.createHotObservable([Recorded<Event<Void>>]())
		let bag = DisposeBag()

		let canCreateWith = scheduler.createObserver((displayName: String, serviceType: String).self)
		let presentError = scheduler.createObserver(Void.self)

		let results = canCreateChatRoom(displayName: displayName, serviceType: serviceType, done: doneButton)

		bag.insert(
			results.canCreateWith.bind(to: canCreateWith),
			results.presentError.bind(to: presentError)
		)

		scheduler.start()

		XCTAssertTrue(canCreateWith.events.isEmpty)
		XCTAssertTrue(presentError.events.isEmpty)
	}

	func testValidData() {
		let scheduler = TestScheduler(initialClock: 0)
		let displayName = scheduler.createHotObservable([.next(10, Optional.some("display-name"))])
		let serviceType = scheduler.createHotObservable([.next(10, Optional.some("service-type"))])
		let doneButton = scheduler.createHotObservable([.next(20, ())])
		let bag = DisposeBag()

		let canCreateWith = scheduler.createObserver((displayName: String, serviceType: String).self)
		let presentError = scheduler.createObserver(Void.self)

		let results = canCreateChatRoom(displayName: displayName, serviceType: serviceType, done: doneButton)

		bag.insert(
			results.canCreateWith.bind(to: canCreateWith),
			results.presentError.bind(to: presentError)
		)

		scheduler.start()

		XCTAssertEqual(canCreateWith.events.map { $0.time }, [20])
		XCTAssertEqual(canCreateWith.events.map { $0.value.element?.displayName }, ["display-name"])
		XCTAssertEqual(canCreateWith.events.map { $0.value.element?.serviceType }, ["service-type"])
		XCTAssertTrue(presentError.events.isEmpty)
	}

	func testInvalidData() {
		let scheduler = TestScheduler(initialClock: 0)
		let displayName = scheduler.createHotObservable([.next(10, Optional.some(""))])
		let serviceType = scheduler.createHotObservable([.next(10, Optional.some(""))])
		let doneButton = scheduler.createHotObservable([.next(20, ())])
		let bag = DisposeBag()

		let canCreateWith = scheduler.createObserver((displayName: String, serviceType: String).self)
		let presentError = scheduler.createObserver(Void.self)

		let results = canCreateChatRoom(displayName: displayName, serviceType: serviceType, done: doneButton)

		bag.insert(
			results.canCreateWith.bind(to: canCreateWith),
			results.presentError.bind(to: presentError)
		)

		scheduler.start()

		XCTAssertTrue(canCreateWith.events.isEmpty)
		XCTAssertTrue(presentError.events.count == 1)
	}
}
