/// Single source of truth for the UI-visible app version string.
///
/// Bumping a release still touches `pubspec.yaml` (the actual package
/// version) and this constant — the two home screens now derive their
/// displayed version from here instead of hardcoding it a second and
/// third time.
const String kAppVersion = 'v1.20.0';
