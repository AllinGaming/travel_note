Purpose

- Show an offline‑friendly app with map, GPS, photo capture, and local storage.

Scope

- Applies to the `travel_note` project only.

Architecture

- Entry (`lib/main.dart`):
  - `TravelNoteApp` configures M3 theme.
  - `Home` manages tabs (Map, Diary) and persistence.
  - Model: `DiaryEntry` with JSON (to/from), optional image path and coordinates.
  - Storage: JSON file in app documents dir; images copied to documents dir.
- Map: `flutter_map` with OpenStreetMap tiles, markers for current location and entries.
- Permissions: Geolocator for location; Image Picker for photos.

Conventions

- Heavy IO on background `Future`s; keep UI responsive.
- If data size grows, move storage into `lib/data/` with a repository interface.
- Follow lints; avoid `print`.

Commands

- `flutter pub get`
- `flutter run` (grant permissions)
- `flutter analyze`, `flutter test`

PR Tips

- If adding offline tile caching, integrate `flutter_map_tile_caching` and document cache location and size policy.

