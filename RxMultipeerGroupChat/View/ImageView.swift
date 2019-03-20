//
//  ImageView.swift
//  RxMultipeerGroupChat
//
//  Created by Daniel Tartaglia on 3/18/19.
//  Copyright © 2019 Daniel Tartaglia. MIT License
//

import UIKit

class ImageView: UIView {
	var transcript: Transcript? {
		didSet {
			guard let transcript = transcript else { return }
			let image = UIImage.init(contentsOfFile: transcript.imageUrl!.path)!
			imageView.image = image

			let imageSize = image.size
			var height = imageSize.height
			let scale: CGFloat

			scale = imageViewHeightMax / height
			height = imageViewHeightMax
			let width = imageSize.width * scale

			let nameText = transcript.peerID.displayName
			let nameSize = ImageView.labelSize(for: nameText, fontSize: nameFontSize)

			let xOffsetBalloon: CGFloat
			let yOffset: CGFloat

			if .send == transcript.direction {
				xOffsetBalloon = 320 - width - imagePaddingX
				yOffset = bufferWhiteSpace / 2
				nameLabel.text = ""
			}
			else {
				xOffsetBalloon = imagePaddingX
				yOffset = bufferWhiteSpace / 2 + nameSize.height - nameOffsetAdjust
				nameLabel.text = nameText
			}

			nameLabel.frame = CGRect(x: xOffsetBalloon, y: 1, width: nameSize.width, height: nameSize.height)
			imageView.frame = CGRect(x: xOffsetBalloon, y: yOffset, width: width, height: height)
		}
	}
	
	private let imageView: UIImageView
	private let nameLabel: UILabel

	required init?(coder aDecoder: NSCoder) {
		imageView = UIImageView()
		imageView.layer.cornerRadius = 5
		imageView.layer.masksToBounds = true
		imageView.layer.borderColor = UIColor.lightGray.cgColor
		imageView.layer.borderWidth = 0.5

		nameLabel = UILabel()
		nameLabel.font = UIFont.systemFont(ofSize: 10)
		nameLabel.textColor = UIColor(red: 34.0/255.0, green: 97.0/255.0, blue: 221.0/255.0, alpha: 1)

		super.init(coder: aDecoder)
		autoresizingMask = [.flexibleWidth, .flexibleHeight]

		addSubview(imageView)
		addSubview(nameLabel)
	}

	static func viewHeight(for transcript: Transcript) -> CGFloat {
		if .receive == transcript.direction {
			return peerNameHeight + imageViewHeightMax + bufferWhiteSpace - nameOffsetAdjust
		}
		else {
			return imageViewHeightMax + bufferWhiteSpace
		}
	}

	private static func labelSize(for string: String, fontSize: CGFloat) -> CGSize {
		return (string as NSString).boundingRect(with: CGSize(width: detailTextLabelWidth, height: 2000), options: .usesLineFragmentOrigin, attributes: [.font: UIFont.systemFont(ofSize: fontSize)], context: nil).size
	}
}

let imageViewTag = 100

private let imageViewHeightMax = 140 as CGFloat
private let imagePaddingX = 15 as CGFloat
private let nameFontSize = 10 as CGFloat
private let bufferWhiteSpace = 14 as CGFloat
private let detailTextLabelWidth = 220 as CGFloat
private let peerNameHeight = 12 as CGFloat
private let nameOffsetAdjust = 4 as CGFloat 
