//
//  SettingsViewController.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/18/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import MultipeerConnectivity
import RxSwift
import RxCocoa

class SettingsViewController: UIViewController {

	var displayName: String = ""
	var serviceType: String = ""

	var didCreateChatRoom: Observable<(displayName: String, serviceType: String)> {
		return _didCreateChatRoom.asObservable()
	}

	private let _didCreateChatRoom = PublishSubject<(displayName: String, serviceType: String)>()
	private let disposeBag = DisposeBag()

	@IBOutlet weak var doneButton: UIBarButtonItem!
	@IBOutlet weak var displayNameTextField: UITextField!
	@IBOutlet weak var serviceTypeTextField: UITextField!

	override func viewDidLoad() {
		super.viewDidLoad()

		displayNameTextField.text = displayName
		serviceTypeTextField.text = serviceType

		let (canCreateWith, presentError) = canCreateChatRoom(displayName: displayNameTextField.rx.text, serviceType: serviceTypeTextField.rx.text, done: doneButton.rx.tap)

		canCreateWith
			.bind(to: _didCreateChatRoom)
			.disposed(by: disposeBag)

		presentError
			.bind(onNext: { [weak self] _ in
				let alert = UIAlertController(title: "Error", message: "You must set a valid room name and your display name", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
				self?.present(alert, animated: true, completion: nil)
			})
			.disposed(by: disposeBag)

		Observable.merge(
			displayNameTextField.rx.controlEvent(.editingDidEndOnExit).asObservable(),
			serviceTypeTextField.rx.controlEvent(.editingDidEndOnExit).asObservable()
			)
			.bind(onNext: { [weak self] in
				self?.view.endEditing(true)
			})
			.disposed(by: disposeBag)
	}
}

func canCreateChatRoom<OS, OV>(displayName: OS, serviceType: OS, done: OV) -> (canCreateWith: Observable<(displayName: String, serviceType: String)>, presentError: Observable<Void>) where OS: ObservableType, OS.E == String?, OV: ObservableType, OV.E == Void {
	let inputValues = Observable.combineLatest(displayName.map { $0 ?? "" }, serviceType.map { $0 ?? "" }) { (displayName: $0, serviceType: $1) }
	let enteredValues = done.withLatestFrom(inputValues)
	let canCreateWith = enteredValues.filter { isValid(displayName: $0.displayName, serviceType: $0.serviceType) }
	let presentError = enteredValues.filter { !isValid(displayName: $0.displayName, serviceType: $0.serviceType) }
	return (canCreateWith, presentError.toVoid())
}

func isValid(displayName: String, serviceType: String) -> Bool {
	let validCharacterSet = CharacterSet(charactersIn: "A"..."Z")
		.union(CharacterSet(charactersIn: "a"..."z"))
		.union(CharacterSet(charactersIn: "0"..."9"))
		.union(CharacterSet(charactersIn: "-"))

	guard !displayName.isEmpty,
		displayName.count <= 63,
		displayName.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }),
		displayName.first! != "-",
		displayName.last! != "-",
		!displayName.containsAdjecentHyphens()
		else { return false }

	guard !serviceType.isEmpty,
		serviceType.count <= 15,
		serviceType.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }),
		serviceType.first! != "-",
		serviceType.last! != "-",
		!serviceType.containsAdjecentHyphens()
		else { return false }

	return true
}

extension String {
	func containsAdjecentHyphens() -> Bool {
		var first = startIndex
		var next = index(after: startIndex)
		while next != endIndex {
			if self[first] == "-" && self[next] == "-" {
				return true
			}
			first = next
			next = index(after: first)
		}
		return false
	}
}
