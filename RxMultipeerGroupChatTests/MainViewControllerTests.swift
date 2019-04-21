//
//  MainViewControllerTests.swift
//  RxMultipeerGroupChatTests
//
//  Created by Daniel Tartaglia on 4/12/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License.
//

import XCTest
import RxSwift
import RxTest
@testable import RxMultipeerGroupChat

class MainViewControllerTests: XCTestCase {

	func testSendEnabled() {
        let scheduler = TestScheduler(initialClock: 0)
        let sendTrigger = scheduler.createHotObservable([.next(20, ())])
        let textEntryDidEnd = scheduler.createHotObservable([.next(40, ())])
        let text = scheduler.createHotObservable([.next(0, ""), .next(10, "hello"), .next(30, "world")])
        let result = scheduler.createObserver(Bool.self)
        let bag = DisposeBag()

        sendEnabled(sendTrigger: sendTrigger, textEntryDidEnd: textEntryDidEnd, text: text)
            .bind(to: result)
            .disposed(by: bag)
		scheduler.start()

		XCTAssertEqual(result.events, [.next(0, false), .next(10, true), .next(20, false), .next(30, true), .next(40, false)])
	}
}
