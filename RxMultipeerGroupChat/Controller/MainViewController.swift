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
			.bind(onNext: { [weak self] in
				guard let this = self else { return }
				print("browseForPeers")

				var browserViewController = MCBrowserViewController(serviceType: this.serviceType, session: this.sessionContainer.session)

				browserViewController.minimumNumberOfPeers = kMCSessionMinimumNumberOfPeers
				browserViewController.maximumNumberOfPeers = kMCSessionMaximumNumberOfPeers
				browserViewController.rx.shouldPresentNearbyPeer = { _, _ in true }
				browserViewController.rx.didFinish()
					.bind(onNext: { [weak self] in
						self?.dismiss(animated: true, completion: nil)
					})
					.disposed(by: this.disposeBag)
				browserViewController.rx.wasCancelled()
					.bind(onNext: { [weak self] in
						self?.dismiss(animated: true, completion: nil)
					})
					.disposed(by: this.disposeBag)

				this.present(browserViewController, animated: true, completion: nil)
			})
			.disposed(by: disposeBag)

		sendPhotoButton.rx.tap
			.flatMap { PHPhotoLibrary.rx.requestAuthorization }
			.filter { $0 == .authorized }
			.observeOn(MainScheduler.instance)
			.bind(onNext: { [weak self] _ in
				guard let this = self else { return }
				let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
				let imagePicker = UIImagePickerController()
				imagePicker.rx.didCancel
					.bind(onNext: { [weak self] in
						self?.dismiss(animated: true, completion: nil)
					})
					.disposed(by: this.disposeBag)
				imagePicker.rx.didFinishPickingMediaWithInfo
					.bind(onNext: { [weak self] info in
						guard let this = self else { return }
						this.dismiss(animated: true, completion: nil)

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

								let transcript = this.sessionContainer.send(imageUrl: imageUrl)

								DispatchQueue.main.async {
									this.insert(transcript: transcript)
								}
							}
							catch {
								print("Unable to write file.")
							}
						}
					})
					.disposed(by: this.disposeBag)
				let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
				let takePhoto = UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
					imagePicker.sourceType = .camera
					this.present(imagePicker, animated: true, completion: nil)
				})
				let chooseExisting = UIAlertAction(title: "Choose Existing", style: .default, handler: { _ in
					imagePicker.sourceType = .photoLibrary
					this.present(imagePicker, animated: true, completion: nil)
				})

				sheet.addAction(cancel)
				sheet.addAction(takePhoto)
				sheet.addAction(chooseExisting)
				this.present(sheet, animated: true, completion: nil)			})
			.disposed(by: disposeBag)

		let shouldSendText = Observable.merge(
			sendMessageButton.rx.tap.asObservable(),
			messageComposeTextField.rx.controlEvent(.editingDidEndOnExit).asObservable()
		)

		Observable.merge(
			shouldSendText
				.map { false },
			messageComposeTextField.rx.text.orEmpty
				.map { !$0.isEmpty }
			)
			.bind(to: sendMessageButton.rx.isEnabled)
			.disposed(by: disposeBag)

		shouldSendText
			.map { "" }
			.bind(to: messageComposeTextField.rx.text)
			.disposed(by: disposeBag)

		shouldSendText
			.withLatestFrom(messageComposeTextField.rx.text.orEmpty)
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
			.bind(onNext: { [weak self] transcript in
				DispatchQueue.main.async {
					self?.insert(transcript: transcript)
				}
			})
			.disposed(by: disposeBag)

		sessionContainer.update
			.bind(onNext: { [weak self] transcript in
				guard let this = self else { return }
				let index = this.imageNameIndex[transcript.imageName]!
				this.transcripts[index] = transcript

				DispatchQueue.main.async {
					let newIndexPath = IndexPath(row: index, section: 0)
					this.tableView.reloadRows(at: [newIndexPath], with: .automatic)
				}
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
