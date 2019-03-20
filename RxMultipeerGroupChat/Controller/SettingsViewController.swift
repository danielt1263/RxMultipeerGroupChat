//
//  SettingsViewController.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/18/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import MultipeerConnectivity

class SettingsViewController: UIViewController {

	weak var delegate: SettingsViewControllerDelegate?
	var displayName: String = ""
	var serviceType: String = ""

	@IBOutlet weak var displayNameTextField: UITextField!
	@IBOutlet weak var serviceTypeTextField: UITextField!

	override func viewDidLoad() {
		super.viewDidLoad()

		displayNameTextField.text = displayName
		serviceTypeTextField.text = serviceType
	}

	@IBAction func doneTapped(_ sender: Any) {
		if isDisplayNameAndSerivceTypeValid {
			delegate?.controller(self, didCreateChatRoomWithDisplayname: displayNameTextField.text ?? "", serviceType: serviceTypeTextField.text ?? "")
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

extension SettingsViewController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		view.endEditing(true)
		return true
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		view.endEditing(true)
	}
}

protocol SettingsViewControllerDelegate: class {
	func controller(_ controller: SettingsViewController, didCreateChatRoomWithDisplayname displayName: String, serviceType: String)
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