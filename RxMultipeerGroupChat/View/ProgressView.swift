//
//  ProgressView.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/18/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit
import RxSwift
import RxCocoa

class ProgressView: UIView {
	var transcript: Transcript? {
		didSet {
			guard let transcript = transcript else { return }
			observer = ProgressObserver.init(name: transcript.imageName, progress: transcript.progress!)
			observer!.changed
				.subscribe(
					onNext: { [weak self] progress in
						self?.observerDidChange(progress: progress)
					},
					onError: { [weak self] _ in
						self?.observerDidCancel()
					},
					onCompleted: { [weak self] in
						self?.observerDidComplete()
					}
				)
				.disposed(by: disposeBag)
			let nameText = transcript.peerID.displayName
			let nameSize = ProgressView.labelSize(for: nameText, fontSize: nameFontSize)

			let xOffset: CGFloat
			let yOffset: CGFloat

			if .send == transcript.direction {
				xOffset = 320 - paddingX - progressViewWidth
				yOffset = bufferWhiteSpace / 2
				displayNameLabel.text = ""
			}
			else {
				xOffset = paddingX
				yOffset = bufferWhiteSpace / 2 + nameSize.height - nameOffsetAdjust
				displayNameLabel.text = nameText
			}

			displayNameLabel.frame = CGRect(x: xOffset, y: 1, width: nameSize.width, height: nameSize.height)
			progressView.frame = CGRect(x: xOffset, y: yOffset + 5, width: progressViewWidth, height: progressViewHeight)
		}
	}

	private let progressView: UIProgressView
	private let displayNameLabel: UILabel
	private var observer: ProgressObserver?
	private let disposeBag = DisposeBag()

	required init?(coder aDecoder: NSCoder) {
		progressView = UIProgressView()
		progressView.progress = 0

		displayNameLabel = UILabel()
		displayNameLabel.font = UIFont.systemFont(ofSize: 10)
		displayNameLabel.textColor = UIColor(red: 34.0/255.0, green: 97.0/255.0, blue: 221.0/255.0, alpha: 1)

		super.init(coder: aDecoder)
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(displayNameLabel)
		addSubview(progressView)
	}

	static func viewHeight(for transcript: Transcript) -> CGFloat {
		if .receive == transcript.direction {
			return peerNameHeight + progressViewHeight + bufferWhiteSpace - nameOffsetAdjust
		}
		else {
			return progressViewHeight + bufferWhiteSpace
		}
	}

	private static func labelSize(for string: String, fontSize: CGFloat) -> CGSize {
		return (string as NSString).boundingRect(with: CGSize(width: progressViewWidth, height: 2000), options: .usesLineFragmentOrigin, attributes: [.font: UIFont.systemFont(ofSize: fontSize)], context: nil).size
	}
}

extension ProgressView {
	func observerDidChange(progress: Progress) {
		DispatchQueue.main.async {
			self.progressView.progress = Float(progress.fractionCompleted)
			print("progress changed completedUnitCount[\(progress.completedUnitCount)]")
		}
	}

	func observerDidCancel() {
		print("progress canceled")
	}

	func observerDidComplete() {
		print("progress complete")
	}
}

let progressViewTag = 101
private let progressViewHeight = 15 as CGFloat
private let paddingX = 15 as CGFloat
private let nameFontSize = 10 as CGFloat
private let bufferWhiteSpace = 14 as CGFloat
private let progressViewWidth = 140 as CGFloat
private let peerNameHeight = 12 as CGFloat
private let nameOffsetAdjust = 4 as CGFloat


