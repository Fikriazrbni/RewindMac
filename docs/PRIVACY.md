# Privacy and permissions

RewindMac reads app usage from macOS Screen Time when you request an import preview. It saves the selected source’s new intervals after you confirm. Protected live history can require Full Disk Access. You can also choose a readable KnowledgeC backup.

## Saved on this Mac

- Application bundle identifiers and display names.
- Session start and end timestamps and assigned categories.
- Preferences, exclusions, custom category names and assignments.

App usage comes from this Mac. RewindMac skips usage from synced devices, website records, and apps excluded from import. The app runs offline and keeps demo data in memory.

Optional launch at login uses `SMAppService.mainApp`. macOS may require approval in System Settings.

## Storage and deletion

RewindMac stores history in SQLite under the user's Application Support folder. FileVault and filesystem permissions protect the disk. Imported usage stays on this Mac until you delete it. CSV and JSON also include saved records from previous versions, and the native save panel lets you choose where exports go.

Deleting saved activity enables SQLite secure deletion, removes sessions, truncates the WAL and vacuums the database. Preferences, macOS Screen Time history, backups and exported files are stored separately from the deleted sessions.
