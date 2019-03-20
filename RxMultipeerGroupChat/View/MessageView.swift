//
//  MessageView.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/17/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit

let messageViewTag = 99

class MessageView: UIView {

	var transcript: Transcript? {
		didSet {
			guard let transcript = transcript else { return }
			let messageText = transcript.message
			messageLabel.text = messageText

			let labelSize = MessageView.labelSize(for: messageText, fontSize: messageFontSize)
			let balloonSize = MessageView.balloonSize(for: labelSize)
			let nameText = transcript.peerID.displayName
			let nameSize = MessageView.labelSize(for: nameText, fontSize: nameFontSize)

			let xOffsetLabel: CGFloat
			let xOffsetBalloon: CGFloat
			let yOffset: CGFloat

			if .send == transcript.direction {
				xOffsetLabel = 320 - labelSize.width - balloonWidthPadding / 2 - 3
				xOffsetBalloon = 320 - balloonSize.width
				yOffset = bufferWhiteSpace / 2
				nameLabel.text = ""
				messageLabel.textColor = .white
				balloonView.image = balloonImageRight.resizableImage(withCapInsets: balloonInsetsRight)
			}
			else {
				xOffsetBalloon = 0
				xOffsetLabel = balloonWidthPadding / 2 + 3
				yOffset = bufferWhiteSpace / 2 + nameSize.height - nameOffsetAdjust
				if .local == transcript.direction {
					nameLabel.text = "Session Admin"
				}
				else {
					nameLabel.text = nameText
				}
				messageLabel.textColor = .darkText
				balloonView.image = balloonImageLeft.resizableImage(withCapInsets: balloonInsetsLeft)
			}
			messageLabel.frame = CGRect(x: xOffsetLabel, y: yOffset + 5, width: labelSize.width, height: labelSize.height)
			balloonView.frame = CGRect(x: xOffsetBalloon, y: yOffset, width: balloonSize.width, height: balloonSize.height)
			nameLabel.frame = CGRect(x: xOffsetLabel - 2, y: 1, width: nameSize.width, height: nameSize.height)
		}
	}

	private let balloonView: UIImageView
	private let messageLabel: UILabel
	private let nameLabel: UILabel
	private let balloonImageLeft: UIImage
	private let balloonImageRight: UIImage
	private let balloonInsetsLeft: UIEdgeInsets
	private let balloonInsetsRight: UIEdgeInsets

	required init?(coder aDecoder: NSCoder) {
		balloonView = UIImageView()
		messageLabel = UILabel()
		messageLabel.numberOfLines = 0

		nameLabel = UILabel()
		nameLabel.font = UIFont.systemFont(ofSize: nameFontSize)
		nameLabel.textColor = UIColor(red: 34.0/255.0, green: 97.0/255.0, blue: 221.0/255.0, alpha: 1)

		balloonImageLeft = #imageLiteral(resourceName: "bubble-left")
		balloonImageRight = #imageLiteral(resourceName: "bubble-right")

		balloonInsetsLeft = UIEdgeInsets(top: balloonInsetTop, left: balloonInsetLeft, bottom: balloonInsetBottom, right: balloonInsetRight)
		balloonInsetsRight = UIEdgeInsets(top: balloonInsetTop, left: balloonInsetLeft, bottom: balloonInsetBottom, right: balloonInsetRight)

		super.init(coder: aDecoder)
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(balloonView)
		addSubview(messageLabel)
		addSubview(nameLabel)
	}

	static func viewHeight(for transcript: Transcript) -> CGFloat {
		let labelHeight = MessageView.balloonSize(for: MessageView.labelSize(for: transcript.message, fontSize: messageFontSize)).height
		if .send != transcript.direction {
			let nameHeight = MessageView.labelSize(for: transcript.peerID.displayName, fontSize: nameFontSize).height
			return labelHeight + nameHeight + bufferWhiteSpace - nameOffsetAdjust
		}
		else {
			return labelHeight + bufferWhiteSpace
		}
	}

	private static func labelSize(for string: String, fontSize: CGFloat) -> CGSize {
		return (string as NSString).boundingRect(with: CGSize(width: detailTextLabelWidth, height: 2000), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [.font: UIFont.systemFont(ofSize: fontSize)], context: nil).size
	}

	private static func balloonSize(for labelSize: CGSize) -> CGSize {
		var balloonSize = CGSize.zero

		if labelSize.height < balloonInsetHeight {
			balloonSize.height = balloonMinHeight
		}
		else {
			balloonSize.height = labelSize.height + balloonHeightPadding
		}

		balloonSize.width = labelSize.width + balloonWidthPadding

		return balloonSize
	}
}

private let messageFontSize = 17 as CGFloat
private let nameFontSize = 10 as CGFloat
private let bufferWhiteSpace = 14 as CGFloat
private let detailTextLabelWidth = 220 as CGFloat
private let nameOffsetAdjust = 4 as CGFloat

private let balloonInsetTop = 30 / 2 as CGFloat
private let balloonInsetLeft = 36 / 2 as CGFloat
private let balloonInsetBottom = 30 / 2 as CGFloat
private let balloonInsetRight = 46 / 2 as CGFloat

private let balloonInsetWidth = balloonInsetLeft + balloonInsetRight
private let balloonInsetHeight = balloonInsetTop + balloonInsetBottom

private let balloonMiddleWidth = 30 / 2 as CGFloat
private let balloonMiddleHeight = 6 / 2 as CGFloat

private let balloonMinHeight = balloonInsetHeight + balloonMiddleHeight

private let balloonHeightPadding = 10 as CGFloat
private let balloonWidthPadding = 30 as CGFloat
