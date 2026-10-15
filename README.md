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
- Undo file moves with Command-Z during the current session.
- Reopen folders with saved category names and shortcuts on this Mac.
- Browse a large photo preview with a compact filmstrip.

Category settings are stored locally in the app's preferences. Photos remain ordinary files in your folders. Undo history lasts for the current session; opening another folder resets it.

## How to Run

Open `PhotoSorter.xcodeproj` in Xcode and run the `PhotoSorter` scheme on macOS.
