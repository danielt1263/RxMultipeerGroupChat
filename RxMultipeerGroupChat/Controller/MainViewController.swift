//
//  MainTableViewController.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import MultipeerConnectivity
import Photos
import RxCocoa
import RxSwift
import UIKit

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

	override func viewDidLoad() {
		super.viewDidLoad()

		let defaults = UserDefaults.standard
		displayName = defaults.string(forKey: kDefaultDisplayName) ?? ""
		serviceType = defaults.string(forKey: kDefaultServiceType) ?? ""

		tableView.keyboardDismissMode = .onDrag

		if !displayName.isEmpty && !serviceType.isEmpty {
			navigationItem.title = serviceType
			createSession()
		}
		else {
			performSegue(withIdentifier: "Room Create", sender: self)
		}

		browseForPeersButton.rx.tap
			.do(onNext: { print("browseForPeers") })
			.flatMap { [weak self] () -> Observable<MCBrowserViewController> in
				guard let this = self else { return Observable.empty() }
				return MCBrowserViewController.rx.createWithParent(self, serviceType: this.serviceType, session: this.sessionContainer.session, configureImagePicker: {
					$0.minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers
					$0.maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers
				}) }
			.flatMap { $0.rx.didFinish() }
			.bind(onNext: { [weak self] in
				self?.dismiss(animated: true, completion: nil)
			})
			.disposed(by: disposeBag)

		struct ImagePickerAction: CustomStringConvertible {
			let description: String
			let configure: (UIImagePickerController) -> Void
		}

		sendPhotoButton.rx.tap
			.flatMap { PHPhotoLibrary.rx.requestAuthorization }
			.filter { $0 == .authorized }
			.observeOn(MainScheduler.instance)
			.flatMap { [weak self] (_) -> Observable<ImagePickerAction> in
				let actions = [
					ImagePickerAction(description: "Take Photo", configure: { $0.sourceType = .camera }),
					ImagePickerAction(description: "Choose Existing", configure: { $0.sourceType = .photoLibrary })
				]
				return UIAlertController.rx.createWithParent(self, title: nil, message: nil, actions: actions, style: .actionSheet, sourceView: nil)
			}
			.flatMap { [weak self] action in
				UIImagePickerController.rx.createWithParent(self, configureImagePicker: action.configure)
			}
			.flatMap { $0.rx.didFinishPickingMediaWithInfo }
			.do(onNext: { [weak self] _ in self?.dismiss(animated: true, completion: nil) })
			.observeOn(SerialDispatchQueueScheduler(qos: .default))
			.map(imageData(from:))
			.flatMap { [weak self] (pngData) -> Observable<Transcript> in
				guard let this = self else { return Observable.empty() }
				let url = imageUrl(with: Date())
				do {
					try pngData?.write(to: url, options: [])
					return Observable.just(this.sessionContainer.send(imageUrl: url))
				}
				catch {
					print("Unable to write file.")
					return Observable.empty()
				}
			}
			.observeOn(MainScheduler.instance)
			.bind(onNext: { [weak self] transcript in
				self?.insert(transcript: transcript)
			})
			.disposed(by: disposeBag)

		sendEnabled(
			sendTrigger: sendMessageButton.rx.tap,
			textEntryDidEnd: messageComposeTextField.rx.controlEvent(.editingDidEndOnExit),
			text: messageComposeTextField.rx.text.orEmpty
			)
			.bind(to: sendMessageButton.rx.isEnabled)
			.disposed(by: disposeBag)

		emptyTextField(
			sendTrigger: sendMessageButton.rx.tap,
			textEntryDidEnd: messageComposeTextField.rx.controlEvent(.editingDidEndOnExit)
			)
			.bind(to: messageComposeTextField.rx.text)
			.disposed(by: disposeBag)

		sendText(
			sendTrigger:sendMessageButton.rx.tap,
			textEntryDidEnd: messageComposeTextField.rx.controlEvent(.editingDidEndOnExit),
			text: messageComposeTextField.rx.text.orEmpty
			)
			.bind(onNext: { [weak self] text in
				guard let this = self else { return }
				if let transcript = this.sessionContainer.send(message: text) {
					this.insert(transcript: transcript)
				}
			})
			.disposed(by: disposeBag)
		NotificationCenter.default.rx.notification(UIResponder.keyboardWillChangeFrameNotification)
			.bind(onNext: { [weak self] notification in
				guard let this = self else { return }
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
				this.navigationController!.toolbar.frame = CGRect(x: this.navigationController!.toolbar.frame.minX, y: keyboardFrame.minY - this.navigationController!.toolbar.frame.height, width: this.navigationController!.toolbar.frame.width, height: this.navigationController!.toolbar.frame.height)
				UIView.commitAnimations()
			})
			.disposed(by: disposeBag)
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "Room Create" {
			let navController = segue.destination as! UINavigationController
			let viewController = navController.topViewController as! SettingsViewController
			viewController.displayName = displayName
			viewController.serviceType = serviceType
			viewController.didCreateChatRoom
				.bind(onNext: { [weak self] displayName, serviceType in
					guard let this = self else { return }
					this.dismiss(animated: true, completion: nil)

					this.displayName = displayName
					this.serviceType = serviceType

					let defaults = UserDefaults.standard
					defaults.set(displayName, forKey: kDefaultDisplayName)
					defaults.set(serviceType, forKey: kDefaultServiceType)

					this.navigationItem.title = serviceType

					this.createSession()
				})
				.disposed(by: disposeBag)
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

	private func createSession() {
		print("create new session")
		sessionContainer = SessionContainer(displayName: displayName, serviceType: serviceType)
		sessionContainer.received
			.observeOn(MainScheduler.instance)
			.bind(onNext: { [weak self] transcript in
				self?.insert(transcript: transcript)
			})
			.disposed(by: disposeBag)

		sessionContainer.update
			.observeOn(MainScheduler.instance)
			.bind(onNext: { [weak self] transcript in
				guard let this = self else { return }
				let index = this.imageNameIndex[transcript.imageName]!
				this.transcripts[index] = transcript
				let newIndexPath = IndexPath(row: index, section: 0)
				this.tableView.reloadRows(at: [newIndexPath], with: .automatic)
			})
			.disposed(by: disposeBag)
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
}

private let kDefaultDisplayName = "displayNameKey"
private let kDefaultServiceType = "serviceTypeKey"

func sendEnabled<OV: ObservableType, OS: ObservableType>(sendTrigger: OV, textEntryDidEnd: OV, text: OS) -> Observable<Bool> where OV.E == Void, OS.E == String  {
	return Observable.merge(sendTrigger.map { false }, textEntryDidEnd.map { false }, text.map { !$0.isEmpty })
}

func emptyTextField<OV: ObservableType>(sendTrigger: OV, textEntryDidEnd: OV) -> Observable<String> where OV.E == Void {
	return Observable.merge(sendTrigger.asObservable(), textEntryDidEnd.asObservable())
		.map { "" }
}

func sendText<OV: ObservableType, OS: ObservableType>(sendTrigger: OV, textEntryDidEnd: OV, text: OS) -> Observable<String> where OV.E == Void, OS.E == String  {
	return Observable.merge(sendTrigger.asObservable(), textEntryDidEnd.asObservable())
		.withLatestFrom(text)
}

func imageData(from info: [UIImagePickerController.InfoKey : Any]) -> Data? {
	let imageToSave = info[.originalImage] as! UIImage
	let pngData = imageToSave.jpegData(compressionQuality: 1.0)
	return pngData
}

func imageUrl(with date: Date) -> URL {
	let imageName = "image-\(inFormat.string(from: date))"
	let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
	return paths[0].appendingPathComponent(imageName)
}

private let inFormat: DateFormatter = {
	let inFormat = DateFormatter()
	inFormat.dateFormat = "yyMMdd-HHmmss"
	return inFormat
}()
