# Backup Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user export every piece of app data — saved players, game history and settings — as one JSON file through the system share sheet, so a copy exists off the device.

**Architecture:** Two layers with a hard boundary. `BackupService.buildBackup()` is pure async data assembly returning a `Map` — no files, no share sheet, fully testable. `BackupService.exportAndShare()` wraps it with the file write and `SharePlus`, mirroring how `game_logger.dart` and the Settings feedback flow already handle files. The Settings screen gains one entry point.

**Tech Stack:** Flutter / Dart, `shared_preferences`, `path_provider` (^2.1.5), `share_plus` (^13.0.0) — all existing dependencies. No new packages.

**Spec:** `docs/superpowers/specs/2026-08-11-elo-seasons-design.md` §6. This is plan 1 of 2; the seasons migration (plan 2) is gated on the export having run.

## Global Constraints

- Code and comments in **English**. UI strings in **English** (a guard test fails the build on Norwegian strings).
- Classic Material screens use `Theme.of(context).colorScheme.<role>`; the Settings screen is classic-track, so no `DossedartTokens` here.
- **The export must never mutate anything.** It reads storage and writes one file outside the app's data. The only write to `SharedPreferences` is the completion timestamp in Task 2.
- Run `flutter analyze lib test` and `flutter test` before each commit.

---

### Task 1: Assemble the backup payload

**Files:**
- Create: `lib/services/backup_service.dart`
- Test: `test/services/backup_service_test.dart` (create)

**Interfaces:**
- Consumes: `PlayerStorage.loadPlayers()`, `GameHistoryService.load()`, `SharedPreferences`.
- Produces:
  - `const String kBackupFormat = 'dart-scorer-backup';`
  - `const int kBackupVersion = 1;`
  - `Future<Map<String, dynamic>> BackupService.buildBackup()`
  - `String BackupService.encode(Map<String, dynamic> backup)` — pretty-printed JSON.
  - `String BackupService.fileName(DateTime now)` — `dart-scorer-backup-YYYY-MM-DD.json`

**Context the implementer needs:**

Storage today lives under three owners, and the payload mirrors them:
- `PlayerStorage` → key `saved_players`, a JSON string of `SavedPlayer.toJson()`.
- `GameHistoryService` → key `game_history_v1`, a JSON string of `GameHistoryEntry.toJson()`.
- `AppSettings` → 23 individual keys of assorted primitive types.

`players` and `history` are stored **parsed**, not as embedded strings, so the file can be read by a human and by a future importer without double-decoding.

`settings` is **every remaining SharedPreferences key**, read generically via `prefs.getKeys()` and `prefs.get(key)`. Enumerating the 23 known keys would silently drop any setting added later — the whole point of a backup is that it does not need maintaining. The two keys already captured above are excluded so the file has one copy of each fact, and the two `*_corrupt` salvage keys are kept: if storage is broken, that is exactly the data worth rescuing.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/backup_service_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/models/game_history.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an empty install still produces a well-formed backup', () async {
    final b = await BackupService.buildBackup();

    expect(b['format'], kBackupFormat);
    expect(b['version'], kBackupVersion);
    expect(b['players'], isEmpty);
    expect(b['history'], isEmpty);
    expect(b['exportedAt'], isA<String>());
    expect(b['app'], isA<String>());
  });

  test('players and history are stored parsed, not as embedded strings',
      () async {
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026), rating: 1310),
    ]);
    await GameHistoryService.record(GameHistoryEntry(
      id: 'g1',
      gameMode: 'x01',
      date: DateTime(2026, 7, 4),
      players: [
        GameHistoryPlayer(
            name: 'Kari', savedPlayerId: 'p1', placement: 1, stats: const {}),
      ],
    ));

    final b = await BackupService.buildBackup();

    expect(b['players'], isA<List>());
    expect((b['players'] as List).first['name'], 'Kari');
    expect((b['players'] as List).first['rating'], 1310);
    expect(b['history'], isA<List>());
    expect((b['history'] as List).first['gameMode'], 'x01');
  });

  test('settings capture every other key, including ones nobody enumerated',
      () async {
    SharedPreferences.setMockInitialValues({
      'meme_enabled': true,
      'meme_frequency': 7,
      'elo_k_new': 32.0,
      'tts_voice': 'en-GB',
      'a_setting_added_next_year': 'still here',
    });

    final b = await BackupService.buildBackup();
    final settings = b['settings'] as Map<String, dynamic>;

    expect(settings['meme_enabled'], true);
    expect(settings['meme_frequency'], 7);
    expect(settings['elo_k_new'], 32.0);
    expect(settings['tts_voice'], 'en-GB');
    expect(settings['a_setting_added_next_year'], 'still here',
        reason: 'a generic sweep must not need updating per new setting');
  });

  test('settings do not duplicate the players and history blobs', () async {
    await PlayerStorage.savePlayers(
        [SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026))]);

    final b = await BackupService.buildBackup();
    final settings = b['settings'] as Map<String, dynamic>;

    expect(settings.containsKey('saved_players'), isFalse);
    expect(settings.containsKey('game_history_v1'), isFalse);
  });

  test('corrupt-salvage keys ARE kept — broken data is worth rescuing',
      () async {
    SharedPreferences.setMockInitialValues({
      'saved_players_corrupt': '{"broken":',
      'game_history_v1_corrupt': '[not json',
    });

    final settings =
        (await BackupService.buildBackup())['settings'] as Map<String, dynamic>;

    expect(settings['saved_players_corrupt'], '{"broken":');
    expect(settings['game_history_v1_corrupt'], '[not json');
  });

  test('the payload encodes to valid JSON and decodes back unchanged',
      () async {
    await PlayerStorage.savePlayers(
        [SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026))]);

    final b = await BackupService.buildBackup();
    final round = jsonDecode(BackupService.encode(b)) as Map<String, dynamic>;

    expect(round['format'], kBackupFormat);
    expect((round['players'] as List).first['id'], 'p1');
  });

  test('the file name carries the date', () {
    expect(BackupService.fileName(DateTime(2026, 8, 11)),
        'dart-scorer-backup-2026-08-11.json');
    expect(BackupService.fileName(DateTime(2026, 12, 5)),
        'dart-scorer-backup-2026-12-05.json');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/backup_service_test.dart`
Expected: FAIL — `Error when reading 'lib/services/backup_service.dart'`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/services/backup_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import 'game_history_service.dart';
import 'player_storage.dart';

const String kBackupFormat = 'dart-scorer-backup';
const int kBackupVersion = 1;

/// Keys captured as parsed structures elsewhere in the payload. Excluded from
/// `settings` so each fact appears once.
const _capturedKeys = {'saved_players', 'game_history_v1'};

/// Exports everything the app stores as one JSON document.
///
/// Reading only — nothing here mutates storage. The point is a copy that
/// leaves the device: `GameHistoryService` keeps just the newest 200 games and
/// strips throws beyond the newest 100, so data is being discarded on ordinary
/// evenings whether or not a migration ever runs.
class BackupService {
  /// Assembles the payload. Pure data — no files, no share sheet — so the
  /// shape can be tested without a platform channel.
  static Future<Map<String, dynamic>> buildBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final players = await PlayerStorage.loadPlayers();
    final history = await GameHistoryService.load();

    // A generic sweep rather than the 23 known AppSettings keys: a backup
    // that needs updating every time a setting is added is a backup that
    // will silently miss one.
    final settings = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_capturedKeys.contains(key)) continue;
      settings[key] = prefs.get(key);
    }

    return {
      'format': kBackupFormat,
      'version': kBackupVersion,
      'app': kAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'players': players.map((p) => p.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'settings': settings,
    };
  }

  /// Pretty-printed so the file is readable by a human deciding whether to
  /// trust it.
  static String encode(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  static String fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'dart-scorer-backup-'
        '${now.year}-${two(now.month)}-${two(now.day)}.json';
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/backup_service_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/backup_service.dart test/services/backup_service_test.dart
git commit -m "feat(backup): assemble the full-data backup payload"
```

---

### Task 2: Write the file, share it, and record that it happened

**Files:**
- Modify: `lib/services/backup_service.dart`
- Modify: `lib/services/app_settings.dart`
- Test: `test/services/backup_service_test.dart` (extend)

**Interfaces:**
- Consumes: `BackupService.buildBackup/encode/fileName` from Task 1.
- Produces:
  - `Future<String> BackupService.writeBackupFile()` — writes the file, returns its path.
  - `Future<void> BackupService.exportAndShare()` — writes, shares, then stamps the timestamp.
  - `Future<DateTime?> AppSettings.getLastBackupAt()` / `Future<void> AppSettings.setLastBackupAt(DateTime)`.
  - `@visibleForTesting static bool BackupService.disableShareForTest`

**Context:** `game_logger.dart:29` uses `getApplicationDocumentsDirectory()` from `path_provider`, and `settings_screen.dart:740-744` shares a file with `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`. Follow both.

The timestamp is stamped **after** the share call returns, and is what plan 2's migration gate reads. `SharePlus` cannot tell us whether the user actually saved the file, so this records "an export was performed", which is the honest claim and the strongest one available.

`disableShareForTest` exists because the share sheet is a platform channel with no binding in a unit test — the same reason `SoundService` and `VideoService` carry `disableForTest`, wired in `test/flutter_test_config.dart`.

- [ ] **Step 1: Write the failing test**

Append to `test/services/backup_service_test.dart`:

```dart
  group('export', () {
    test('writes a file whose contents decode back to the payload', () async {
      BackupService.disableShareForTest = true;
      addTearDown(() => BackupService.disableShareForTest = false);
      await PlayerStorage.savePlayers(
          [SavedPlayer(id: 'p1', name: 'Kari', createdAt: DateTime(2026))]);

      final path = await BackupService.writeBackupFile();

      expect(path, endsWith('.json'));
      final decoded =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(decoded['format'], kBackupFormat);
      expect((decoded['players'] as List).first['name'], 'Kari');
    });

    test('exporting stamps the timestamp the migration gate reads', () async {
      BackupService.disableShareForTest = true;
      addTearDown(() => BackupService.disableShareForTest = false);

      expect(await AppSettings.getLastBackupAt(), isNull);
      await BackupService.exportAndShare();
      expect(await AppSettings.getLastBackupAt(), isNotNull);
    });
  });
```

Add `import 'dart:io';` and imports for `AppSettings` at the top of the file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/backup_service_test.dart`
Expected: FAIL — `disableShareForTest`, `writeBackupFile`, `exportAndShare` and `getLastBackupAt` are undefined.

- [ ] **Step 3: Write the implementation**

Add to `lib/services/app_settings.dart`, beside the other keys:

```dart
  // Backup
  static const String _lastBackupAtKey = 'last_backup_at';

  /// When a full-data backup was last exported, or null if never. Plan 2's
  /// seasons migration refuses to run until this is set.
  static Future<DateTime?> getLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> setLastBackupAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupAtKey, value.toIso8601String());
  }
```

Add to `lib/services/backup_service.dart` — imports first:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_settings.dart';
```

then inside the class:

```dart
  /// The share sheet is a platform channel with no binding in a unit test —
  /// same reason SoundService and VideoService carry a disableForTest.
  @visibleForTesting
  static bool disableShareForTest = false;

  /// Writes the backup into the app's documents directory and returns its
  /// path. Overwrites same-day exports rather than accumulating copies.
  static Future<String> writeBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${fileName(DateTime.now())}');
    await file.writeAsString(encode(await buildBackup()));
    return file.path;
  }

  /// Writes the file, hands it to the system share sheet, then records that
  /// an export happened.
  ///
  /// The stamp lands AFTER the share returns. SharePlus cannot report whether
  /// the user actually saved anything, so this records "an export was
  /// performed" — the honest claim, and the strongest one available.
  static Future<void> exportAndShare() async {
    final path = await writeBackupFile();
    if (!disableShareForTest) {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        subject: 'Dart Scorer - data backup',
      ));
    }
    await AppSettings.setLastBackupAt(DateTime.now());
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/backup_service_test.dart`
Expected: PASS — 9 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/backup_service.dart lib/services/app_settings.dart test/services/backup_service_test.dart
git commit -m "feat(backup): write and share the backup file"
```

---

### Task 3: The Settings entry point

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/screens/settings_backup_test.dart` (create)

**Interfaces:**
- Consumes: `BackupService.exportAndShare()`, `AppSettings.getLastBackupAt()`.
- Produces: nothing later tasks depend on.

**Context:** The Settings screen is classic Material (`colorScheme` roles, `ListTile`, `Card`), not DOSSEDART. Follow the surrounding sections; the feedback/share flow near line 679 is the closest sibling.

Copy, exact:
- Section title: `DATA`
- Tile title: `Export backup`
- Subtitle when never exported: `Players, game history and settings as one file`
- Subtitle once exported: `Last exported <d MMM yyyy>`

The subtitle is the whole point of showing the date — a backup you cannot date is a backup you cannot trust.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/settings_backup_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/screens/settings_screen.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/backup_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackupService.disableShareForTest = true;
  });
  tearDown(() => BackupService.disableShareForTest = false);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('offers an export, and says it has never run', (tester) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('Export backup'), 300);

    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Players, game history and settings as one file'),
        findsOneWidget);
  });

  testWidgets('exporting records the date and shows it', (tester) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('Export backup'), 300);

    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();

    expect(await AppSettings.getLastBackupAt(), isNotNull);
    expect(find.textContaining('Last exported'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_backup_test.dart`
Expected: FAIL — no widget with text `Export backup`.

- [ ] **Step 3: Write the implementation**

In `settings_screen.dart`, add `DateTime? _lastBackupAt;` to the state, load it in the existing settings-loading method alongside the other reads (`_lastBackupAt = await AppSettings.getLastBackupAt();` inside the same `setState`), and add a `DATA` section built like its neighbours:

```dart
  Widget _backupTile() {
    final at = _lastBackupAt;
    return ListTile(
      leading: const Icon(Icons.save_alt),
      title: const Text('Export backup'),
      subtitle: Text(
        at == null
            ? 'Players, game history and settings as one file'
            : 'Last exported ${_formatBackupDate(at)}',
      ),
      onTap: () async {
        await BackupService.exportAndShare();
        final at = await AppSettings.getLastBackupAt();
        if (mounted) setState(() => _lastBackupAt = at);
      },
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatBackupDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
```

Add the import `import '../services/backup_service.dart';`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/settings_backup_test.dart && flutter test`
Expected: PASS — the whole suite. If `scrollUntilVisible` cannot find the tile, check which scrollable the Settings screen uses and pass that finder rather than raising the frame size.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart test/screens/settings_backup_test.dart
git commit -m "feat(backup): Export backup entry point in Settings"
```

---

## Self-Review

**Spec coverage.** §6 asks for one JSON file with saved players, game history and settings, exported through the system share sheet, reusing `share_plus`, with the export recorded so the migration can gate on it. Task 1 builds the payload, Task 2 writes/shares/stamps, Task 3 exposes it. §6's out-of-scope note (import) is respected — nothing here reads a backup back.

**Placeholder scan.** No TBDs; every step carries real code. The one judgement call left to the implementer is which scrollable finder Settings needs in Task 3 Step 4, and the fallback is stated rather than left as "handle it".

**Type consistency.** `buildBackup` → `Map<String, dynamic>` is consumed by `encode` in Task 1 and `writeBackupFile` in Task 2. `fileName(DateTime)` is defined in Task 1 and called in Task 2. `getLastBackupAt()` → `Future<DateTime?>` is defined in Task 2 and read in Task 3 and by plan 2. `disableShareForTest` is introduced in Task 2 and reused in Task 3's `setUp`.

**Deliberate limitation, stated in the code.** The timestamp records that an export was *performed*, not that the user saved the file — `SharePlus` does not report the outcome. Plan 2's gate inherits that limitation, which is why the gate is friction rather than a guarantee.
