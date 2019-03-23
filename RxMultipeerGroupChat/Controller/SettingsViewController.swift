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

		doneButton.rx.tap
			.bind(onNext: { [weak self] in self?.doneTapped() })
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

	func doneTapped() {
		if isDisplayNameAndSerivceTypeValid {
			_didCreateChatRoom.onNext((displayNameTextField.text ?? "", serviceType: serviceTypeTextField.text ?? ""))
		}
		else {
			let alert = UIAlertController(title: "Error", message: "You must set a valid room name and your display name", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
			present(alert, animated: true, completion: nil)
		}
	}

	private var isDisplayNameAndSerivceTypeValid: Bool {
		let validCharacterSet = CharacterSet(charactersIn: "A"..."Z")
			.union(CharacterSet(charactersIn: "a"..."z"))
			.union(CharacterSet(charactersIn: "0"..."9"))
			.union(CharacterSet(charactersIn: "-"))

		guard let displayName = displayNameTextField.text,
			!displayName.isEmpty,
			displayName.count <= 63,
			displayName.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }),
			displayName.first! != "-",
			displayName.last! != "-",
			!displayName.containsAdjecentHyphens()
			else { return false }
		let peerID = MCPeerID(displayName: displayName)

		guard let serviceType = serviceTypeTextField.text,
			!serviceType.isEmpty,
			serviceType.count <= 15,
			serviceType.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }),
			serviceType.first! != "-",
			serviceType.last! != "-",
			!serviceType.containsAdjecentHyphens()
			else { return false }
		let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceTypeTextField.text ?? "")
		print("Room Name [\(advertiser.serviceType)] (aka service type) and display name [\(peerID.displayName)] are valid")

		return true
	}
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
