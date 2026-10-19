<img width="1983" height="793" alt="gh header" src="https://github.com/user-attachments/assets/653ed806-11ec-41c7-816a-5b002a474425" />

# PhotoSorter

PhotoSorter is a native macOS app for quickly sorting loose image files into category folders with keyboard shortcuts.

It is designed for photos that are not part of your macOS Photos library. Choose a folder, create categories, then assign each image with a single key. PhotoSorter moves the file into the matching category folder immediately.

[Demo](https://kunat.dev/notes/photosorter-release/)

## Features

- Sort `.jpg`, `.jpeg`, `.png`, and `.heic` files.
- Create categories with single-letter or digit shortcuts.
- Navigate with arrow keys and inspect the selected photo with Space (Quick Look).
- Change a photo's category directly, or press Delete to return it to the chosen folder.
- Rotate and crop photos with **Edit** (Command-E).
- Delete a photo with **Delete Photo** (Command-Delete).
- Undo edits, deletions, and file moves with Command-Z during the current session.
- Reopen folders with saved category names and shortcuts on this Mac.
- Browse a large photo preview with a compact filmstrip.
- Right-click a filmstrip photo to edit it, change its category, copy the file, inspect it with Quick Look, show it in Finder, or delete it.

Category settings are stored locally in the app's preferences. Photos remain ordinary files in your folders. Undo history lasts for the current session; opening another folder resets it.

## Edit and recover photos

Select **Edit** to open the editor with rotation and cropping ready to use. Adjust the **Rotate** slider or enter an angle for fine rotation from −45° to 45° in 0.1° steps. Fine rotation trims the edges to keep the frame filled. **Rotate 90°** makes a quarter turn. Drag the crop frame’s corners to resize it, or drag inside the frame to move it. **Reset Crop** restores the full frame. **Undo** reverses each adjustment. Select **Save** to apply rotation and cropping together, or **Cancel** to discard your edits.

Before saving an edit or deleting a photo, PhotoSorter copies the original file into its Application Support directory, outside your sorting folder. Select **Show Recovery Folder** to find these copies in Finder. Each copy includes a `source-path.txt` file with its previous location. Recovery copies remain after you quit or open another folder; you can remove them manually when you no longer need them.

The main **Undo** button restores the last saved edit, deletion, or move. Undo history resets when you open another folder or quit. JPEG and HEIC edits are re-encoded when saved; undo restores the exact previous file. Photos with animation or multiple images cannot be edited.

## How to Run

Open `PhotoSorter.xcodeproj` in Xcode and run the `PhotoSorter` scheme on macOS.
