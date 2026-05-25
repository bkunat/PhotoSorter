//
//  PhotoSorter
//

import AppKit

private final class CategoryBadgeBackgroundView: NSView {
    var fillColor: NSColor = .clear {
        didSet { needsLayout = true }
    }

    var strokeColor: NSColor = .clear {
        didSet { needsLayout = true }
    }

    var shadowColor: NSColor? {
        didSet { needsLayout = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeBackingLayer() -> CALayer {
        CALayer()
    }

    override func layout() {
        super.layout()
        applyAppearance()
    }

    private func applyAppearance() {
        guard let layer else { return }

        layer.backgroundColor = fillColor.cgColor
        layer.borderColor = strokeColor.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = bounds.height / 2
        layer.cornerCurve = .continuous
        layer.shadowColor = shadowColor?.cgColor
        layer.shadowOpacity = shadowColor == nil ? 0 : 1
        layer.shadowRadius = shadowColor == nil ? 0 : 12
        layer.shadowOffset = shadowColor == nil ? .zero : NSSize(width: 0, height: -3)
        layer.masksToBounds = false
    }
}

final class PhotoCarouselItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("PhotoCarouselItem")

    private let imageContainerView = NSView()
    private let previewImageView = NSImageView()
    private let imageTintOverlayView = NSView()
    private let footerContainerView = NSView()
    private let categoryBadgeView = CategoryBadgeBackgroundView()
    private let categoryBadgeLabel = NSTextField(labelWithString: "")
    private let positionLabel = NSTextField(labelWithString: "")
    private let filenameLabel = NSTextField(labelWithString: "")
    private let placeholderSymbolView = NSImageView()
    private let placeholderLabel = NSTextField(labelWithString: "Preview unavailable")
    private var accentTintColor = NSColor.controlAccentColor
    private var baseCardBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94)
    private var selectedCardBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
    private var baseFooterBackgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
    private var selectedFooterBackgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.98)
    private var imageOverlayColor = NSColor.clear
    private var showsImageTintOverlay = false
    private var representedPhotoURL: URL?

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance(animated: true)
        }
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        view.layer?.cornerRadius = 30
        view.layer?.cornerCurve = .continuous
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.16
        view.layer?.shadowRadius = 30
        view.layer?.shadowOffset = NSSize(width: 0, height: -12)
        view.layer?.masksToBounds = false

        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.wantsLayer = true
        imageContainerView.layer?.backgroundColor = NSColor.tertiarySystemFill.cgColor
        imageContainerView.layer?.cornerRadius = 24
        imageContainerView.layer?.cornerCurve = .continuous
        imageContainerView.layer?.borderWidth = 1
        imageContainerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        imageContainerView.layer?.masksToBounds = true

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.masksToBounds = true

        imageTintOverlayView.translatesAutoresizingMaskIntoConstraints = false
        imageTintOverlayView.wantsLayer = true
        imageTintOverlayView.layer?.backgroundColor = NSColor.clear.cgColor
        imageTintOverlayView.alphaValue = 0

        footerContainerView.translatesAutoresizingMaskIntoConstraints = false
        footerContainerView.wantsLayer = true
        footerContainerView.layer?.backgroundColor = baseFooterBackgroundColor.cgColor
        footerContainerView.layer?.cornerRadius = 18
        footerContainerView.layer?.cornerCurve = .continuous
        footerContainerView.layer?.borderWidth = 1
        footerContainerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        footerContainerView.layer?.masksToBounds = true

        categoryBadgeView.translatesAutoresizingMaskIntoConstraints = false
        categoryBadgeView.alphaValue = 0

        categoryBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryBadgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        categoryBadgeLabel.textColor = .labelColor
        categoryBadgeLabel.lineBreakMode = .byTruncatingTail
        categoryBadgeLabel.maximumNumberOfLines = 1
        categoryBadgeLabel.alignment = .center

        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        positionLabel.textColor = .secondaryLabelColor
        positionLabel.alignment = .left

        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        filenameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        filenameLabel.textColor = .labelColor
        filenameLabel.lineBreakMode = .byTruncatingMiddle
        filenameLabel.maximumNumberOfLines = 1

        placeholderSymbolView.translatesAutoresizingMaskIntoConstraints = false
        placeholderSymbolView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        placeholderSymbolView.contentTintColor = .secondaryLabelColor
        placeholderSymbolView.image = NSImage(systemSymbolName: "photo.badge.exclamationmark", accessibilityDescription: nil)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = .systemFont(ofSize: 14, weight: .medium)
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.alignment = .center

        let placeholderStack = NSStackView(views: [placeholderSymbolView, placeholderLabel])
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.orientation = .vertical
        placeholderStack.alignment = .centerX
        placeholderStack.spacing = 10

        footerContainerView.addSubview(filenameLabel)
        footerContainerView.addSubview(positionLabel)

        imageContainerView.addSubview(previewImageView)
        imageContainerView.addSubview(imageTintOverlayView)
        imageContainerView.addSubview(placeholderStack)
        imageContainerView.addSubview(categoryBadgeView)
        categoryBadgeView.addSubview(categoryBadgeLabel)

        view.addSubview(imageContainerView)
        view.addSubview(footerContainerView)

        NSLayoutConstraint.activate([
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            imageContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            imageContainerView.bottomAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: -10),
            imageContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),

            previewImageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),

            imageTintOverlayView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            imageTintOverlayView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            imageTintOverlayView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            imageTintOverlayView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),

            placeholderStack.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor),

            categoryBadgeView.topAnchor.constraint(equalTo: imageContainerView.topAnchor, constant: 12),
            categoryBadgeView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor, constant: -12),
            categoryBadgeView.heightAnchor.constraint(equalToConstant: 28),

            categoryBadgeLabel.leadingAnchor.constraint(equalTo: categoryBadgeView.leadingAnchor, constant: 13),
            categoryBadgeLabel.trailingAnchor.constraint(equalTo: categoryBadgeView.trailingAnchor, constant: -13),
            categoryBadgeLabel.centerYAnchor.constraint(equalTo: categoryBadgeView.centerYAnchor),

            footerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            footerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            footerContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            footerContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            filenameLabel.leadingAnchor.constraint(equalTo: footerContainerView.leadingAnchor, constant: 14),
            filenameLabel.trailingAnchor.constraint(equalTo: footerContainerView.trailingAnchor, constant: -14),
            filenameLabel.topAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: 10),

            positionLabel.leadingAnchor.constraint(equalTo: footerContainerView.leadingAnchor, constant: 14),
            positionLabel.trailingAnchor.constraint(equalTo: footerContainerView.trailingAnchor, constant: -14),
            positionLabel.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 2),
            positionLabel.bottomAnchor.constraint(equalTo: footerContainerView.bottomAnchor, constant: -10)
        ])

        applyNeutralAppearance()
        updateSelectionAppearance(animated: false)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedPhotoURL = nil
        previewImageView.image = nil
        placeholderSymbolView.isHidden = false
        placeholderLabel.isHidden = false
        categoryBadgeView.alphaValue = 0
        categoryBadgeLabel.stringValue = ""
        view.toolTip = nil
        applyNeutralAppearance()
    }

    func configure(
        photo: PhotoItem,
        positionText: String,
        category: Category?,
        previewLoader: PhotoCarouselPreviewLoader
    ) {
        representedObject = photo
        representedPhotoURL = photo.currentURL
        positionLabel.stringValue = positionText
        filenameLabel.stringValue = photo.filename
        view.toolTip = photo.currentURL.path

        switch photo.status {
        case .uncategorized:
            applyNeutralAppearance()
            hideCategoryBadge()
        case .categorized:
            let categoryTint: NSColor
            if let category {
                categoryTint = CategoryColorPalette.color(for: category)
            } else {
                categoryTint = CategoryColorPalette.automaticColor(fallbackName: photo.filename)
            }
            applyCategorizedAppearance(tint: categoryTint)
            showCategoryBadge(title: category?.name ?? "Categorized", tint: categoryTint)
        }

        if let cachedImage = previewLoader.cachedPreview(for: photo.currentURL) {
            apply(image: cachedImage)
            return
        }

        apply(image: nil)
        previewLoader.loadPreview(for: photo, reasonDescription: "displaying carousel item") { [weak self] image in
            guard let self else { return }
            guard self.representedPhotoURL == photo.currentURL else { return }
            guard (self.representedObject as? PhotoItem)?.id == photo.id else { return }

            self.apply(image: image)
        }
    }

    private func apply(image: NSImage?) {
        previewImageView.image = image
        let placeholderIsHidden = image != nil
        placeholderSymbolView.isHidden = placeholderIsHidden
        placeholderLabel.isHidden = placeholderIsHidden
    }

    private func applyNeutralAppearance() {
        accentTintColor = .controlAccentColor
        baseCardBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94)
        selectedCardBackgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.985)
        baseFooterBackgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92)
        selectedFooterBackgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.98)
        imageOverlayColor = .clear
        showsImageTintOverlay = false
        imageContainerView.layer?.backgroundColor = NSColor.tertiarySystemFill.cgColor
        imageTintOverlayView.layer?.backgroundColor = imageOverlayColor.cgColor
        categoryBadgeLabel.textColor = .labelColor
        categoryBadgeView.fillColor = .clear
        categoryBadgeView.strokeColor = .clear
        categoryBadgeView.shadowColor = nil
        updateSelectionAppearance(animated: false)
    }

    private func applyCategorizedAppearance(tint: NSColor) {
        accentTintColor = tint
        baseCardBackgroundColor = tint.blended(withFraction: 0.54, of: .windowBackgroundColor) ?? .windowBackgroundColor
        selectedCardBackgroundColor = tint.blended(withFraction: 0.4, of: .windowBackgroundColor) ?? .windowBackgroundColor
        baseFooterBackgroundColor = tint.blended(withFraction: 0.74, of: .controlBackgroundColor) ?? .controlBackgroundColor
        selectedFooterBackgroundColor = tint.blended(withFraction: 0.58, of: .controlBackgroundColor) ?? .controlBackgroundColor
        imageOverlayColor = tint.withAlphaComponent(0.36)
        showsImageTintOverlay = true
        imageTintOverlayView.layer?.backgroundColor = imageOverlayColor.cgColor
        imageContainerView.layer?.backgroundColor = (
            tint.blended(withFraction: 0.68, of: .tertiarySystemFill) ?? .tertiarySystemFill
        ).cgColor
        updateSelectionAppearance(animated: false)
    }

    private func showCategoryBadge(title: String, tint: NSColor) {
        categoryBadgeLabel.stringValue = title
        let badgeColor = vibrantBadgeColor(for: tint)
        categoryBadgeView.fillColor = badgeColor
        categoryBadgeView.strokeColor = NSColor.white.withAlphaComponent(0.34)
        categoryBadgeView.shadowColor = badgeColor.blended(withFraction: 0.5, of: .black)
            ?? NSColor.black.withAlphaComponent(0.34)
        categoryBadgeLabel.textColor = .white
        categoryBadgeView.alphaValue = 1
    }

    private func hideCategoryBadge() {
        categoryBadgeView.alphaValue = 0
        categoryBadgeLabel.stringValue = ""
        categoryBadgeView.shadowColor = nil
    }

    private func updateSelectionAppearance(animated: Bool) {
        let updates = {
            self.view.layer?.backgroundColor = (self.isSelected
                ? self.selectedCardBackgroundColor
                : self.baseCardBackgroundColor).cgColor
            self.view.layer?.borderWidth = self.isSelected ? 2 : 1.2
            self.view.layer?.shadowColor = self.showsImageTintOverlay
                ? self.accentTintColor.withAlphaComponent(self.isSelected ? 0.52 : 0.32).cgColor
                : NSColor.black.cgColor
            self.view.layer?.borderColor = self.isSelected
                ? self.accentTintColor.withAlphaComponent(0.96).cgColor
                : self.accentTintColor.withAlphaComponent(0.58).cgColor
            self.view.layer?.shadowOpacity = self.isSelected ? 0.3 : 0.2
            self.view.layer?.shadowRadius = self.isSelected ? 42 : 34
            self.imageContainerView.layer?.borderColor = NSColor.white.withAlphaComponent(
                self.showsImageTintOverlay ? 0.16 : 0.08
            ).cgColor
            self.imageTintOverlayView.alphaValue = self.showsImageTintOverlay ? (self.isSelected ? 1 : 0.98) : 0
            self.footerContainerView.layer?.backgroundColor = self.isSelected
                ? self.selectedFooterBackgroundColor.cgColor
                : self.baseFooterBackgroundColor.cgColor
            self.footerContainerView.layer?.borderColor = self.accentTintColor.withAlphaComponent(
                self.showsImageTintOverlay
                    ? (self.isSelected ? 0.54 : 0.38)
                    : 0.08
            ).cgColor
            self.positionLabel.alphaValue = self.isSelected ? 1 : 0.8
            self.categoryBadgeView.alphaValue = self.categoryBadgeLabel.stringValue.isEmpty
                ? 0
                : 1
        }

        guard animated else {
            updates()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            updates()
        }
    }

    private func vibrantBadgeColor(for tint: NSColor) -> NSColor {
        guard let color = tint.usingColorSpace(.deviceRGB) else {
            return tint
        }

        return NSColor(
            hue: color.hueComponent,
            saturation: min(max(color.saturationComponent * 1.35, 0.8), 1),
            brightness: min(max(color.brightnessComponent * 0.82, 0.58), 0.82),
            alpha: 1
        )
    }

}
