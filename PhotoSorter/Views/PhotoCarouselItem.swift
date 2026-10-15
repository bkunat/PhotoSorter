//
//  PhotoSorter
//

import AppKit

final class PhotoCarouselItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("PhotoCarouselItem")

    private let previewButton = NSButton()
    private let filenameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private var representedPhotoID: PhotoItem.ID?
    private var representedPhotoURL: URL?
    var onSelect: (() -> Void)?

    override var isSelected: Bool {
        didSet { updateSelectionAppearance() }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 6

        previewButton.translatesAutoresizingMaskIntoConstraints = false
        previewButton.isBordered = false
        previewButton.imagePosition = .imageOnly
        previewButton.imageScaling = .scaleProportionallyUpOrDown
        previewButton.target = self
        previewButton.action = #selector(selectPhoto)
        previewButton.setAccessibilityHelp("Select photo")

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.setAccessibilityLabel("Loading preview")

        for label in [filenameLabel, statusLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.alignment = .center
            label.lineBreakMode = .byTruncatingMiddle
            label.maximumNumberOfLines = 1
            label.setAccessibilityElement(false)
        }
        filenameLabel.font = .systemFont(ofSize: 10)
        statusLabel.font = .systemFont(ofSize: 9)
        statusLabel.textColor = .secondaryLabelColor

        view.addSubview(previewButton)
        view.addSubview(progressIndicator)
        view.addSubview(filenameLabel)
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            previewButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 3),
            previewButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            previewButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            previewButton.heightAnchor.constraint(equalToConstant: 60),
            progressIndicator.centerXAnchor.constraint(equalTo: previewButton.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: previewButton.centerYAnchor),
            filenameLabel.topAnchor.constraint(equalTo: previewButton.bottomAnchor, constant: 2),
            filenameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            filenameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            statusLabel.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 1),
            statusLabel.leadingAnchor.constraint(equalTo: filenameLabel.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: filenameLabel.trailingAnchor)
        ])
        updateSelectionAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedPhotoID = nil
        representedPhotoURL = nil
        previewButton.image = nil
        progressIndicator.stopAnimation(nil)
        onSelect = nil
    }

    func configure(
        photo: PhotoItem,
        positionText: String,
        category: Category?,
        previewLoader: PhotoCarouselPreviewLoader
    ) {
        let samePhoto = representedPhotoID == photo.id
        representedPhotoID = photo.id
        representedPhotoURL = photo.currentURL
        filenameLabel.stringValue = photo.filename
        statusLabel.stringValue = category?.name ?? "Unsorted"
        previewButton.toolTip = "\(photo.filename) — \(statusLabel.stringValue)"
        previewButton.setAccessibilityLabel("\(photo.filename), \(statusLabel.stringValue), \(positionText)")
        if !samePhoto {
            previewButton.image = nil
        }
        progressIndicator.startAnimation(nil)
        previewLoader.loadPreview(for: photo, priority: .normal) { [weak self] image in
            guard let self, self.representedPhotoID == photo.id,
                  self.representedPhotoURL == photo.currentURL else { return }
            self.progressIndicator.stopAnimation(nil)
            self.previewButton.image = image ?? NSImage(
                systemSymbolName: "photo.badge.exclamationmark",
                accessibilityDescription: "Preview unavailable"
            )
        }
        updateSelectionAppearance()
    }

    private func updateSelectionAppearance() {
        guard isViewLoaded else { return }
        view.layer?.borderWidth = isSelected ? 2 : 0
        view.layer?.borderColor = NSColor.controlAccentColor.cgColor
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        previewButton.setAccessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    @objc private func selectPhoto() {
        onSelect?()
    }
}
