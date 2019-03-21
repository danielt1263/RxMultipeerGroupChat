//
//  MainTableViewController.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import MultipeerConnectivity
import RxSwift
import RxCocoa

class MainViewController: UITableViewController {
	private var displayName: String = ""
	private var serviceType: String = ""
	private var sessionContainer: SessionContainer!
	private var transcripts: [Transcript] = []
	private var imageNameIndex: [String: Int] = [:]
	private let disposeBag = DisposeBag()
	@IBOutlet weak var browseForPeersButton: UIBarButtonItem!
	@IBOutlet weak var sendPhotoButton: UIBarButtonItem!
	@IBOutlet weak var messageComposeTextField: UITextField!
	@IBOutlet weak var sendMessageButton: UIBarButtonItem!

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		let defaults = UserDefaults.standard
		displayName = defaults.string(forKey: kDefaultDisplayName) ?? ""
		serviceType = defaults.string(forKey: kDefaultServiceType) ?? ""

		if !displayName.isEmpty && !serviceType.isEmpty {
			navigationItem.title = serviceType
			createSession()
		}
		else {
			performSegue(withIdentifier: "Room Create", sender: self)
		}

		browseForPeersButton.rx.tap
			.subscribe(onNext: { [weak self] in self?.browseForPeers() })
			.disposed(by: disposeBag)

		sendMessageButton.rx.tap
			.subscribe(onNext: { [weak self] in self?.sendMessageTapped() })
			.disposed(by: disposeBag)

		sendPhotoButton.rx.tap
			.subscribe(onNext: { [weak self] in self?.photoButtonTapped() })
			.disposed(by: disposeBag)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		NotificationCenter.default.removeObserver(self)
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "Room Create" {
			let navController = segue.destination as! UINavigationController
			let viewController = navController.topViewController as! SettingsViewController
			viewController.delegate = self
			viewController.displayName = displayName
			viewController.serviceType = serviceType
		}
	}

	// MARK: UITableViewDataSource
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return transcripts.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let transcript = transcripts[indexPath.row]

		let cell: UITableViewCell
		if transcript.imageUrl != nil {
			cell = tableView.dequeueReusableCell(withIdentifier: "Image Cell", for: indexPath)
			let imageView = cell.viewWithTag(imageViewTag) as! ImageView
			imageView.transcript = transcript
		}
		else if transcript.progress != nil {
			cell = tableView.dequeueReusableCell(withIdentifier: "Progress Cell", for: indexPath)
			let progressView = cell.viewWithTag(progressViewTag) as! ProgressView
			progressView.transcript = transcript
		}
		else {
			cell = tableView.dequeueReusableCell(withIdentifier: "Message Cell", for: indexPath)
			let messageView = cell.viewWithTag(messageViewTag) as! MessageView
			messageView.transcript = transcript
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let transcript = transcripts[indexPath.row]
		if transcript.imageUrl != nil {
			return ProgressView.viewHeight(for: transcript)
		}
		else {
			return MessageView.viewHeight(for: transcript)
		}
	}

	func browseForPeers() {
		print("browseForPeers")

		let browserViewController = MCBrowserViewController(serviceType: serviceType, session: sessionContainer.session)

		browserViewController.delegate = self
		browserViewController.minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers
		browserViewController.maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers

		present(browserViewController, animated: true, completion: nil)
	}

	func sendMessageTapped() {
		messageComposeTextField.resignFirstResponder()
	}

	func photoButtonTapped() {
		let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		let imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		let takePhoto = UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
			imagePicker.sourceType = .camera
			self.present(imagePicker, animated: true, completion: nil)
		})
		let chooseExisting = UIAlertAction(title: "Choose Existing", style: .default, handler: { _ in
			imagePicker.sourceType = .photoLibrary
			self.present(imagePicker, animated: true, completion: nil)
		})

		sheet.addAction(cancel)
		sheet.addAction(takePhoto)
		sheet.addAction(chooseExisting)
		present(sheet, animated: true, completion: nil)
	}

	private func createSession() {
		print("create new session")
		sessionContainer = SessionContainer(displayName: displayName, serviceType: serviceType)
		sessionContainer.delegate = self
	}

	private func insert(transcript: Transcript) {
		transcripts.append(transcript)
		if transcript.progress != nil {
			let transcriptIndex = transcripts.count - 1
			imageNameIndex[transcript.imageName] = transcriptIndex
		}

		let newIndexPath = IndexPath(row: transcripts.count - 1, section: 0)
		tableView.insertRows(at: [newIndexPath], with: .fade)

		let numberOfRows = tableView.numberOfRows(inSection: 0)
		if numberOfRows > 0 {
			tableView.scrollToRow(at: IndexPath(row: numberOfRows - 1, section: 0), at: .bottom, animated: true)
		}
	}

	private func moveToolBar(up: Bool, forKeyboardNotification notification: Notification) {
		let userInfo = notification.userInfo!

		var animationDuration: TimeInterval = 0
		var animationCurve: UIView.AnimationCurve = UIView.AnimationCurve.easeInOut
		var keyboardFrame: CGRect = CGRect.zero
		(userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSValue).getValue(&animationCurve)
		(userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSValue).getValue(&animationDuration)
		(userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).getValue(&keyboardFrame)

		UIView.beginAnimations(nil, context: nil)
		UIView.setAnimationDuration(animationDuration)
		UIView.setAnimationCurve(animationCurve)

		navigationController!.toolbar.frame = CGRect(x: navigationController!.toolbar.frame.minX, y: navigationController!.toolbar.frame.minY + keyboardFrame.height * (up ? -1 : 1), width: navigationController!.toolbar.frame.width, height: navigationController!.toolbar.frame.height)
		UIView.commitAnimations()
	}

	@objc func keyboardWillShow(_ notification: Notification) {
		moveToolBar(up: true, forKeyboardNotification: notification)
	}

	@objc func keyboardWillHide(_ notification: Notification) {
		moveToolBar(up: false, forKeyboardNotification: notification)
	}
}

extension MainViewController: SettingsViewControllerDelegate {
	func controller(_ controller: SettingsViewController, didCreateChatRoomWithDisplayname displayName: String, serviceType: String) {
		dismiss(animated: true, completion: nil)

		self.displayName = displayName
		self.serviceType = serviceType

		let defaults = UserDefaults.standard
		defaults.set(displayName, forKey: kDefaultDisplayName)
		defaults.set(serviceType, forKey: kDefaultServiceType)

		navigationItem.title = serviceType

		createSession()
	}
}

extension MainViewController: MCBrowserViewControllerDelegate {
	func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
		return true
	}

	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		browserViewController.dismiss(animated: true, completion: nil)
	}

	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		browserViewController.dismiss(animated: true, completion: nil)
	}
}

extension MainViewController: SessionContainerDelegate {
	func received(transcript: Transcript) {
		DispatchQueue.main.async {
			self.insert(transcript: transcript)
		}
	}

	func update(transcript: Transcript) {
		let index = imageNameIndex[transcript.imageName]!
		transcripts[index] = transcript

		DispatchQueue.main.async {
			let newIndexPath = IndexPath(row: index, section: 0)
			self.tableView.reloadRows(at: [newIndexPath], with: .automatic)
		}
	}
}

extension MainViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {

	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true, completion: nil)
	}

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		picker.dismiss(animated: true, completion: nil)

		DispatchQueue.global().async {
			let imageToSave = info[.originalImage] as! UIImage

			let pngData = imageToSave.jpegData(compressionQuality: 1.0)

			let inFormat = DateFormatter()
			inFormat.dateFormat = "yyMMdd-HHmmss"
			let imageName = "image-\(inFormat.string(from: Date()))"
			let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
			let imageUrl = paths[0].appendingPathComponent(imageName)
			do {
				try pngData?.write(to: imageUrl, options: [])

				let transcript = self.sessionContainer.send(imageUrl: imageUrl)

				DispatchQueue.main.async {
					self.insert(transcript: transcript)
				}
			}
			catch {
				print("Unable to write file.")
			}
		}
	}
}

extension MainViewController: UITextFieldDelegate {
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let length = (messageComposeTextField.text?.count ?? 0) - range.length + string.count
		if length > 0 {
			sendMessageButton.isEnabled = true
		}
		else {
			sendMessageButton.isEnabled = false
		}
		return true
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.endEditing(true)
		return true
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		if let text = messageComposeTextField.text, !text.isEmpty {
			textField.resignFirstResponder()
		}

		if let transcript = sessionContainer.send(message: messageComposeTextField.text ?? "") {
			insert(transcript: transcript)
		}

		messageComposeTextField.text = ""
		sendMessageButton.isEnabled = false
	}
}

private let kDefaultDisplayName = "displayNameKey"
private let kDefaultServiceType = "serviceTypeKey"
