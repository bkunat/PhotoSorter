//
//  PhotoSorter
//

import AppKit

final class PhotoCarouselItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("PhotoCarouselItem")

    private let previewButton = NSButton()
    private let filenameLabel = NSTextField(labelWithString: "")
    private let categoryBadge = CategoryBadgeView()
    private let categoryDot = NSView()
    private let categoryLabel = NSTextField(labelWithString: "")
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

        for label in [filenameLabel, categoryLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.alignment = .center
            label.lineBreakMode = .byTruncatingMiddle
            label.maximumNumberOfLines = 1
            label.setAccessibilityElement(false)
        }
        filenameLabel.font = .systemFont(ofSize: 10)
        categoryLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        categoryLabel.textColor = .white
        categoryLabel.alignment = .left

        categoryBadge.translatesAutoresizingMaskIntoConstraints = false
        categoryBadge.wantsLayer = true
        categoryBadge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        categoryBadge.layer?.cornerRadius = 9
        categoryBadge.isHidden = true
        categoryBadge.setAccessibilityElement(false)
        categoryDot.translatesAutoresizingMaskIntoConstraints = false
        categoryDot.wantsLayer = true
        categoryDot.layer?.cornerRadius = 3
        categoryDot.setAccessibilityElement(false)
        categoryBadge.addSubview(categoryDot)
        categoryBadge.addSubview(categoryLabel)

        view.addSubview(previewButton)
        view.addSubview(progressIndicator)
        view.addSubview(categoryBadge)
        view.addSubview(filenameLabel)
        NSLayoutConstraint.activate([
            previewButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 3),
            previewButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            previewButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            previewButton.heightAnchor.constraint(equalToConstant: 72),
            progressIndicator.centerXAnchor.constraint(equalTo: previewButton.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: previewButton.centerYAnchor),
            categoryBadge.topAnchor.constraint(equalTo: previewButton.topAnchor, constant: 4),
            categoryBadge.leadingAnchor.constraint(equalTo: previewButton.leadingAnchor, constant: 4),
            categoryBadge.trailingAnchor.constraint(lessThanOrEqualTo: previewButton.trailingAnchor, constant: -4),
            categoryBadge.heightAnchor.constraint(equalToConstant: 18),
            categoryDot.leadingAnchor.constraint(equalTo: categoryBadge.leadingAnchor, constant: 6),
            categoryDot.centerYAnchor.constraint(equalTo: categoryBadge.centerYAnchor),
            categoryDot.widthAnchor.constraint(equalToConstant: 6),
            categoryDot.heightAnchor.constraint(equalToConstant: 6),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryDot.trailingAnchor, constant: 4),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryBadge.trailingAnchor, constant: -6),
            categoryLabel.centerYAnchor.constraint(equalTo: categoryBadge.centerYAnchor),
            filenameLabel.topAnchor.constraint(equalTo: previewButton.bottomAnchor, constant: 2),
            filenameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            filenameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3)
        ])
        updateSelectionAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedPhotoID = nil
        representedPhotoURL = nil
        previewButton.image = nil
        categoryBadge.isHidden = true
        categoryLabel.stringValue = ""
        categoryDot.layer?.backgroundColor = nil
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
        categoryLabel.stringValue = category?.name ?? ""
        categoryDot.layer?.backgroundColor = category.map { CategoryColorPalette.color(for: $0).cgColor }
        categoryBadge.isHidden = category == nil
        let status = category?.name ?? "Unsorted"
        previewButton.toolTip = "\(photo.filename) — \(status)"
        previewButton.setAccessibilityLabel("\(photo.filename), \(status), \(positionText)")
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

    private final class CategoryBadgeView: NSView {
        // The badge belongs to the thumbnail's existing selection target.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
