//
//  PhotoSorter
//

import Foundation

enum SessionError: LocalizedError, Equatable {
    case noFolderSelected
    case scanFailed(folderName: String, underlying: String)
    case recentDirectoryUnavailable(String)
    case emptyCategoryName
    case invalidCategoryName(String)
    case unsupportedShortcut
    case duplicateCategoryName(String)
    case duplicateShortcut(String)
    case categoryFolderConflict(String)
    case tooManyCategories(categoryCount: Int, shortcutCount: Int)
    case categoryRenameFailed(name: String, underlying: String)
    case categoryRenameRecoveryRequired(name: String, recoveryPath: String, underlying: String)
    case invalidCategory
    case noCurrentPhoto
    case photoAlreadyCategorized
    case sourceFileMissing(String)
    case destinationConflict(String)
    case moveFailed(filename: String, underlying: String)
    case unsafePhotoFile(String)
    case recoveryStorageInWorkingDirectory
    case photoChangedExternally(String)
    case editFailed(filename: String, underlying: String)
    case deleteFailed(filename: String, underlying: String)
    case nothingToUndo
    case undoSourceMissing(String)
    case undoConflict(String)
    case undoFailed(filename: String, underlying: String)
    case unexpected(String)

    var alertTitle: String {
        switch self {
        case .noFolderSelected:
            "Choose a Folder First"
        case .scanFailed:
            "Could Not Read Folder"
        case .recentDirectoryUnavailable:
            "Recent Folder Unavailable"
        case .emptyCategoryName, .invalidCategoryName, .unsupportedShortcut, .duplicateCategoryName, .duplicateShortcut:
            "Invalid Category"
        case .categoryFolderConflict:
            "Category Folder Exists"
        case .tooManyCategories:
            "Too Many Categories"
        case .categoryRenameFailed, .categoryRenameRecoveryRequired:
            "Could Not Rename Category"
        case .invalidCategory:
            "Category Missing"
        case .noCurrentPhoto:
            "No Photo Selected"
        case .photoAlreadyCategorized:
            "Photo Already Sorted"
        case .sourceFileMissing:
            "Photo Missing"
        case .destinationConflict:
            "File Conflict"
        case .moveFailed:
            "Move Failed"
        case .unsafePhotoFile:
            "Cannot Change Photo"
        case .recoveryStorageInWorkingDirectory:
            "Recovery Folder Conflict"
        case .photoChangedExternally:
            "Photo Changed"
        case .editFailed:
            "Could Not Save Photo"
        case .deleteFailed:
            "Could Not Delete Photo"
        case .nothingToUndo:
            "Nothing To Undo"
        case .undoSourceMissing:
            "Photo Missing"
        case .undoConflict:
            "Cannot Restore Photo"
        case .undoFailed:
            "Undo Failed"
        case .unexpected:
            "Unexpected Error"
        }
    }

    var errorDescription: String? {
        switch self {
        case .noFolderSelected:
            "Select a folder before adding categories or sorting photos."
        case let .scanFailed(folderName, _):
            "PhotoSorter could not scan `\(folderName)` for supported image files."
        case let .recentDirectoryUnavailable(folderName):
            "`\(folderName)` is no longer available as a recent folder."
        case .emptyCategoryName:
            "Category names cannot be empty."
        case let .invalidCategoryName(name):
            "`\(name)` cannot be used as a category folder name."
        case .unsupportedShortcut:
            "Shortcuts must be a single letter or digit."
        case let .duplicateCategoryName(name):
            "A category named `\(name)` already exists in this session."
        case let .duplicateShortcut(shortcut):
            "The shortcut `\(shortcut)` is already assigned to another category."
        case let .categoryFolderConflict(path):
            "A folder already exists at `\(path)`."
        case let .tooManyCategories(categoryCount, shortcutCount):
            """
            This project has \(categoryCount) category folders, but PhotoSorter could only assign \
            \(shortcutCount) unique shortcuts.
            """
        case let .categoryRenameFailed(name, _):
            "PhotoSorter could not rename the category folder for `\(name)`."
        case let .categoryRenameRecoveryRequired(name, recoveryPath, _):
            "PhotoSorter could not finish renaming `\(name)` or restore its original folder. Your files remain at `\(recoveryPath)`."
        case .invalidCategory:
            "That category no longer exists in the current session."
        case .noCurrentPhoto:
            "There is no current photo to work with."
        case .photoAlreadyCategorized:
            "The selected photo has already been categorized."
        case let .sourceFileMissing(filename):
            "`\(filename)` is no longer in the expected location."
        case let .destinationConflict(path):
            "A file already exists at `\(path)`."
        case let .moveFailed(filename, _):
            "PhotoSorter could not move `\(filename)` into its category folder."
        case let .unsafePhotoFile(filename):
            "`\(filename)` must be a regular file inside the working folder, without symbolic or hard links."
        case .recoveryStorageInWorkingDirectory:
            "The working folder contains PhotoSorter's recovery folder. Choose a narrower working folder so original photos remain outside it."
        case let .photoChangedExternally(filename):
            "`\(filename)` changed outside PhotoSorter. This action was stopped to preserve those changes."
        case let .editFailed(filename, _):
            "PhotoSorter could not save edits to `\(filename)`."
        case let .deleteFailed(filename, _):
            "PhotoSorter could not delete `\(filename)`."
        case .nothingToUndo:
            "There is no session action to reverse."
        case let .undoSourceMissing(filename):
            "`\(filename)` is missing from its expected location, so it cannot be restored."
        case let .undoConflict(path):
            "A file already exists at the original location: `\(path)`."
        case let .undoFailed(filename, _):
            "PhotoSorter could not restore `\(filename)`."
        case let .unexpected(message):
            message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .scanFailed(_, let underlying):
            underlying
        case .recentDirectoryUnavailable:
            "Choose the folder again to restore access. PhotoSorter removed the unavailable recent entry."
        case .emptyCategoryName:
            "Enter a non-empty folder name for the category."
        case .invalidCategoryName:
            "Use a single folder name without a leading period or path separators."
        case .unsupportedShortcut:
            "Use one unmodified alphanumeric key, for example `D` or `1`."
        case .duplicateCategoryName:
            "Rename the category or continue using the existing one."
        case .duplicateShortcut:
            "Assign a different shortcut so every category remains unique."
        case .categoryFolderConflict:
            "Choose a different category name or move the conflicting folder first."
        case .tooManyCategories:
            "Remove or merge category folders, then reopen the project."
        case .categoryRenameFailed(_, let underlying):
            underlying
        case .categoryRenameRecoveryRequired(_, _, let underlying):
            "In Finder, choose Go > Go to Folder and enter the path above. Restore the folder, then reopen it in PhotoSorter. \(underlying)"
        case .photoAlreadyCategorized:
            "Use the arrow keys to find an uncategorized photo or undo the last action."
        case .sourceFileMissing:
            "Check whether the file was moved or deleted outside PhotoSorter."
        case .destinationConflict:
            "Rename or move the existing file, then try the categorization again."
        case .moveFailed(_, let underlying):
            underlying
        case .undoSourceMissing:
            "Check whether the moved file was changed outside PhotoSorter."
        case .undoConflict:
            "Move or rename the conflicting file at the original location, then try undo again."
        case .undoFailed(_, let underlying), .editFailed(_, let underlying), .deleteFailed(_, let underlying):
            underlying
        case .photoChangedExternally:
            "Reopen the photo or folder to review the current file before trying again."
        case .unsafePhotoFile, .recoveryStorageInWorkingDirectory:
            nil
        case .noFolderSelected, .invalidCategory, .noCurrentPhoto, .nothingToUndo, .unexpected:
            nil
        }
    }
}
