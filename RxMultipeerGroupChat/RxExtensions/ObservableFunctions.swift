//
//  ObservableFunctions.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 4/14/19.
//  Copyright © 2019 Daniel Tartaglia. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType {
	func discardNil<T>() -> Observable<T> where Element == T? {
		return filter { $0 != nil }.map { $0! }
	}

	func toVoid() -> Observable<Void> {
		return map { _ in }
	}
}
