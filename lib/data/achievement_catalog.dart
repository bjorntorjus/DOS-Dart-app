import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/achievement_event.dart';

// The achievement catalog — single source of truth for *what* badges exist.
// Pure data; evaluation lives in AchievementService. Glyphs are Material icons
// for now (spec decision #7: art-ready, swap to assets later).
//
// Naming rule (spec decision #1): every name is globally unique, OR a concept
// shared identically across modes is a single cross-cutting badge. No
// `Name (mode)` duplicates.
//
// This is wave 1: cross-cutting + per-mode volume + cheap per-game feats —
// everything unlockable from data the app already tracks (retro-grantable),
// plus the marquee streak/event badges that light up once the per-mode tracking
// phases land.

// ---- helpers -------------------------------------------------------------

AchievementGlyph _g(IconData i) => AchievementGlyph.icon(i);

int _modeWon(AchievementContext ctx, String key) =>
    ctx.player.modeStats[key]?.won ?? 0;
int _modePlayed(AchievementContext ctx, String key) =>
    ctx.player.modeStats[key]?.played ?? 0;
int _modeCounter(AchievementContext ctx, String key, String counter) =>
    ctx.player.modeStats[key]?.get(counter) ?? 0;

/// Cricket spans two mode keys (standard + cutthroat).
int _cricketWon(AchievementContext ctx) =>
    _modeWon(ctx, 'cricket') + _modeWon(ctx, 'cricket_cutthroat');
int _cricketCounter(AchievementContext ctx, String c) =>
    _modeCounter(ctx, 'cricket', c) + _modeCounter(ctx, 'cricket_cutthroat', c);

// ---- catalog -------------------------------------------------------------

/// Builds the full catalog. A function (not a const) because predicates are
/// closures. Cached by [achievementCatalog].
List<Achievement> _build() => [
      // ===================== CROSS-CUTTING: volume =====================
      Achievement(
        id: 'x_rookie',
        name: 'ROOKIE',
        description: 'Finish your first game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.sports_esports),
        milestoneTest: (ctx) => ctx.player.gamesPlayed >= 1,
      ),
      Achievement(
        id: 'x_regular',
        name: 'REGULAR',
        description: 'Play 25 games',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.videogame_asset),
        milestoneTest: (ctx) => ctx.player.gamesPlayed >= 25,
      ),
      Achievement(
        id: 'x_grinder',
        name: 'GRINDER',
        description: 'Play 100 games',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.repeat),
        milestoneTest: (ctx) => ctx.player.gamesPlayed >= 100,
      ),
      Achievement(
        id: 'x_veteran',
        name: 'VETERAN',
        description: 'Play 250 games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.military_tech),
        milestoneTest: (ctx) => ctx.player.gamesPlayed >= 250,
      ),
      Achievement(
        id: 'x_arcade_rat',
        name: 'ARCADE RAT',
        description: 'Play 500 games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.gamepad),
        milestoneTest: (ctx) => ctx.player.gamesPlayed >= 500,
      ),
      Achievement(
        id: 'x_first_blood',
        name: 'FIRST BLOOD',
        description: 'Win your first game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.emoji_events),
        milestoneTest: (ctx) => ctx.player.gamesWon >= 1,
      ),
      Achievement(
        id: 'x_winner',
        name: 'WINNER WINNER',
        description: 'Win 25 games',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.emoji_events),
        milestoneTest: (ctx) => ctx.player.gamesWon >= 25,
      ),
      Achievement(
        id: 'x_centurion',
        name: 'CENTURION',
        description: 'Win 100 games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.workspace_premium),
        milestoneTest: (ctx) => ctx.player.gamesWon >= 100,
      ),
      Achievement(
        id: 'x_half_decent',
        name: 'HALF-DECENT',
        description: '50% win rate over 20+ games',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.percent),
        milestoneTest: (ctx) =>
            ctx.player.gamesPlayed >= 20 && ctx.player.winRate >= 0.5,
      ),
      Achievement(
        id: 'x_shark',
        name: 'SHARK',
        description: '70% win rate over 30+ games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.water),
        milestoneTest: (ctx) =>
            ctx.player.gamesPlayed >= 30 && ctx.player.winRate >= 0.7,
      ),

      // ===================== CROSS-CUTTING: versatility =====================
      Achievement(
        id: 'x_dabbler',
        name: 'DABBLER',
        description: 'Play 3 different modes',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.shuffle),
        milestoneTest: (ctx) => ctx.player.modeStats.keys
                .where((k) => (ctx.player.modeStats[k]?.played ?? 0) > 0)
                .length >=
            3,
      ),
      Achievement(
        id: 'x_decathlete',
        name: 'DECATHLETE',
        description: 'Play every game mode',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.grid_view),
        milestoneTest: (ctx) {
          const modes = ['x01', 'cricket', 'aroundTheClock', 'killer', 'halveIt', 'shanghai'];
          return modes.every((m) =>
              (ctx.player.modeStats[m]?.played ?? 0) > 0 ||
              (m == 'cricket' &&
                  (ctx.player.modeStats['cricket_cutthroat']?.played ?? 0) > 0));
        },
      ),
      Achievement(
        id: 'x_jack_of_all',
        name: 'JACK OF ALL',
        description: 'Win in every game mode',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.auto_awesome),
        milestoneTest: (ctx) {
          const modes = ['x01', 'aroundTheClock', 'killer', 'halveIt', 'shanghai'];
          final cricketWon = _cricketWon(ctx) > 0;
          return cricketWon && modes.every((m) => (ctx.player.modeStats[m]?.won ?? 0) > 0);
        },
      ),

      // ===================== CROSS-CUTTING: ELO =====================
      Achievement(
        id: 'x_ranked',
        name: 'RANKED',
        description: 'Cross 1250 rating',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.trending_up),
        milestoneTest: (ctx) => ctx.player.rating >= 1250,
      ),
      Achievement(
        id: 'x_contender',
        name: 'CONTENDER',
        description: 'Cross 1350 rating',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.trending_up),
        milestoneTest: (ctx) => ctx.player.rating >= 1350,
      ),
      Achievement(
        id: 'x_master',
        name: 'MASTER',
        description: 'Cross 1450 rating',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.grade),
        milestoneTest: (ctx) => ctx.player.rating >= 1450,
      ),
      Achievement(
        id: 'x_grandmaster',
        name: 'GRANDMASTER',
        description: 'Cross 1550 rating',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.diamond),
        milestoneTest: (ctx) => ctx.player.rating >= 1550,
      ),
      Achievement(
        id: 'x_the_floor',
        name: 'THE FLOOR',
        description: 'Bottom out at the 100 rating floor',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.south),
        milestoneTest: (ctx) => ctx.player.rating <= 100,
      ),
      Achievement(
        id: 'x_giant_slayer',
        name: 'GIANT SLAYER',
        description: 'Beat an opponent rated 200+ above you',
        tier: AchievementTier.gold,
        category: AchievementCategory.social,
        glyph: _g(Icons.bolt),
        milestoneTest: (ctx) {
          final o = ctx.outcome;
          if (o == null || !o.won) return false;
          final hardest = o.opponentRatingsBefore.fold<double>(0, (m, r) => r > m ? r : m);
          return hardest - o.ratingBefore >= 200;
        },
      ),

      // ===================== CROSS-CUTTING: social / quirky =====================
      Achievement(
        id: 'x_party_host',
        name: 'PARTY HOST',
        description: 'Finish a game with 4+ players',
        tier: AchievementTier.silver,
        category: AchievementCategory.social,
        glyph: _g(Icons.groups),
        milestoneTest: (ctx) => (ctx.outcome?.playerCount ?? 0) >= 4,
      ),
      Achievement(
        id: 'x_natural_talent',
        name: 'NATURAL TALENT',
        description: 'Win the very first game you ever play',
        tier: AchievementTier.silver,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.auto_awesome),
        milestoneTest: (ctx) =>
            (ctx.outcome?.won ?? false) && ctx.player.gamesPlayed == 1,
      ),
      Achievement(
        id: 'x_rivalry',
        name: 'RIVALRY',
        description: 'Beat the same opponent 5 times',
        tier: AchievementTier.bronze,
        category: AchievementCategory.social,
        glyph: _g(Icons.sports_kabaddi),
        milestoneTest: (ctx) =>
            ctx.player.headToHead.values.any((h) => h.wins >= 5),
      ),
      Achievement(
        id: 'x_nemesis',
        name: 'NEMESIS',
        description: 'Beat the same opponent 15 times',
        tier: AchievementTier.silver,
        category: AchievementCategory.social,
        glyph: _g(Icons.local_fire_department),
        milestoneTest: (ctx) =>
            ctx.player.headToHead.values.any((h) => h.wins >= 15),
      ),
      Achievement(
        id: 'x_punching_bag',
        name: 'PUNCHING BAG',
        description: 'Lose to the same opponent 10 times',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.sentiment_very_dissatisfied),
        milestoneTest: (ctx) =>
            ctx.player.headToHead.values.any((h) => h.losses >= 10),
      ),
      Achievement(
        id: 'x_social_butterfly',
        name: 'SOCIAL BUTTERFLY',
        description: 'Beat 5+ different opponents',
        tier: AchievementTier.silver,
        category: AchievementCategory.social,
        glyph: _g(Icons.diversity_3),
        milestoneTest: (ctx) =>
            ctx.player.headToHead.values.where((h) => h.wins >= 1).length >= 5,
      ),
      Achievement(
        id: 'x_quitter',
        name: 'QUITTER',
        description: 'Leave 5 games midway',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.exit_to_app),
        milestoneTest: (ctx) => ctx.player.gamesLeftMidway >= 5,
      ),
      Achievement(
        id: 'x_substitute',
        name: 'SUBSTITUTE',
        description: 'Join 5 games midway',
        tier: AchievementTier.bronze,
        category: AchievementCategory.social,
        glyph: _g(Icons.login),
        milestoneTest: (ctx) => ctx.player.gamesJoinedMidway >= 5,
      ),

      // ===================== CROSS-CUTTING: streaks (light up in phase 6) =====================
      Achievement(
        id: 'x_hot_start',
        name: 'HOT START',
        description: 'Win 3 games in a row',
        tier: AchievementTier.bronze,
        category: AchievementCategory.streak,
        glyph: _g(Icons.whatshot),
        milestoneTest: (ctx) => ctx.player.bestWinStreak >= 3,
      ),
      Achievement(
        id: 'x_on_fire',
        name: 'ON FIRE',
        description: 'Win 5 games in a row',
        tier: AchievementTier.silver,
        category: AchievementCategory.streak,
        glyph: _g(Icons.local_fire_department),
        milestoneTest: (ctx) => ctx.player.bestWinStreak >= 5,
      ),
      Achievement(
        id: 'x_unstoppable',
        name: 'UNSTOPPABLE',
        description: 'Win 10 games in a row',
        tier: AchievementTier.gold,
        category: AchievementCategory.streak,
        glyph: _g(Icons.rocket_launch),
        milestoneTest: (ctx) => ctx.player.bestWinStreak >= 10,
      ),
      Achievement(
        id: 'x_cold_streak',
        name: 'COLD STREAK',
        description: 'Lose 5 games in a row',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.ac_unit),
        milestoneTest: (ctx) => ctx.player.currentLossStreak >= 5,
      ),

      // ===================== X01 =====================
      Achievement(
        id: 'x01_the_grinder',
        name: 'OCHE REGULAR',
        description: 'Play 10 X01 games',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.sports_bar),
        mode: 'x01',
        milestoneTest: (ctx) => _modePlayed(ctx, 'x01') >= 10,
      ),
      Achievement(
        id: 'x01_centurion',
        name: 'OCHE VETERAN',
        description: 'Play 100 X01 games',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.sports_bar),
        mode: 'x01',
        milestoneTest: (ctx) => _modePlayed(ctx, 'x01') >= 100,
      ),
      Achievement(
        id: 'x01_ton_of_tons',
        name: 'TON OF TONS',
        description: 'Score 100+ in a turn 100 times',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.add_chart),
        mode: 'x01',
        milestoneTest: (ctx) => _modeCounter(ctx, 'x01', 'turnsOver100') >= 100,
      ),
      Achievement(
        id: 'x01_checkout_artist',
        name: 'CHECKOUT ARTIST',
        description: 'Record 50 checkouts',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.flag),
        mode: 'x01',
        milestoneTest: (ctx) => _modeCounter(ctx, 'x01', 'checkouts') >= 50,
      ),
      Achievement(
        id: 'x01_double_trouble',
        name: 'DOUBLE TROUBLE',
        description: 'Hit 100 doubles',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.looks_two),
        mode: 'x01',
        milestoneTest: (ctx) => _modeCounter(ctx, 'x01', 'doublesHit') >= 100,
      ),
      Achievement(
        id: 'x01_treble_tycoon',
        name: 'TREBLE TYCOON',
        description: 'Hit 500 trebles',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.looks_3),
        mode: 'x01',
        milestoneTest: (ctx) => _modeCounter(ctx, 'x01', 'triplesHit') >= 500,
      ),
      Achievement(
        id: 'x01_big_fish',
        name: 'BIG FISH',
        description: 'Check out from 170',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.set_meal),
        mode: 'x01',
        milestoneTest: (ctx) => _modeCounter(ctx, 'x01', 'bestCheckout') >= 170,
      ),
      Achievement(
        id: 'x01_ton_plus_checkout',
        name: 'TON-PLUS FINISH',
        description: 'Check out from 100 or more',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.flag_circle),
        mode: 'x01',
        milestoneTest: (ctx) => _modeCounter(ctx, 'x01', 'bestCheckout') >= 100,
      ),
      // X01 event badges (light up when phase-5 wires the events)
      Achievement(
        id: 'x01_maximum',
        name: 'MAXIMUM',
        description: 'Score a 180 in one turn',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.whatshot),
        mode: 'x01',
        event: AchievementEvent.score180,
      ),
      Achievement(
        id: 'x01_bullseye_finish',
        name: 'BULLSEYE FINISH',
        description: 'Win a leg on the bull',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.adjust),
        mode: 'x01',
        event: AchievementEvent.bullFinish,
      ),
      Achievement(
        id: 'x01_treble_trouble',
        name: 'TREBLE TROUBLE',
        description: 'Hit three trebles in a single turn',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.filter_3),
        mode: 'x01',
        event: AchievementEvent.threeTreblesTurn,
      ),
      Achievement(
        id: 'x01_three_black',
        name: 'THREE IN THE BLACK',
        description: 'Hit three bulls in a single turn',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.adjust),
        mode: 'x01',
        event: AchievementEvent.threeBullsTurn,
      ),
      Achievement(
        id: 'x01_surgeon',
        name: 'SURGEON',
        description: 'Win an X01 game without a single bust',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.healing),
        mode: 'x01',
        milestoneTest: (ctx) {
          final o = ctx.outcome;
          if (o == null || !o.won || o.mode.name != 'x01') return false;
          return o.counter('bustCount') == 0;
        },
      ),

      // ===================== CRICKET =====================
      Achievement(
        id: 'cri_closer',
        name: 'CLOSER',
        description: 'Win a standard Cricket game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.close),
        mode: 'cricket',
        milestoneTest: (ctx) => _modeWon(ctx, 'cricket') >= 1,
      ),
      Achievement(
        id: 'cri_throat_cutter',
        name: 'THROAT CUTTER',
        description: 'Win a Cutthroat Cricket game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.content_cut),
        mode: 'cricket',
        milestoneTest: (ctx) => _modeWon(ctx, 'cricket_cutthroat') >= 1,
      ),
      Achievement(
        id: 'cri_veteran_closer',
        name: 'VETERAN CLOSER',
        description: 'Win 25 Cricket games',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.done_all),
        mode: 'cricket',
        milestoneTest: (ctx) => _cricketWon(ctx) >= 25,
      ),
      Achievement(
        id: 'cri_marksman',
        name: 'MARKSMAN',
        description: 'Score 50 career marks',
        tier: AchievementTier.bronze,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.check),
        mode: 'cricket',
        milestoneTest: (ctx) => _cricketCounter(ctx, 'marksScored') >= 50,
      ),
      Achievement(
        id: 'cri_mark_hunter',
        name: 'MARK HUNTER',
        description: 'Score 500 career marks',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.checklist),
        mode: 'cricket',
        milestoneTest: (ctx) => _cricketCounter(ctx, 'marksScored') >= 500,
      ),
      Achievement(
        id: 'cri_mark_lord',
        name: 'MARK LORD',
        description: 'Score 2000 career marks',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.verified),
        mode: 'cricket',
        milestoneTest: (ctx) => _cricketCounter(ctx, 'marksScored') >= 2000,
      ),
      Achievement(
        id: 'cri_the_nine',
        name: 'THE NINE',
        description: 'Nine marks in a single turn',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.grid_3x3),
        mode: 'cricket',
        event: AchievementEvent.nineMarkTurn,
      ),

      // ===================== AROUND THE CLOCK =====================
      Achievement(
        id: 'atc_clockwork',
        name: 'CLOCKWORK',
        description: 'Win your first Around the Clock game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.schedule),
        mode: 'aroundTheClock',
        milestoneTest: (ctx) => _modeWon(ctx, 'aroundTheClock') >= 1,
      ),
      Achievement(
        id: 'atc_clock_master',
        name: 'CLOCK MASTER',
        description: 'Win 25 Around the Clock games',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.av_timer),
        mode: 'aroundTheClock',
        milestoneTest: (ctx) => _modeWon(ctx, 'aroundTheClock') >= 25,
      ),
      Achievement(
        id: 'atc_timelord',
        name: 'TIMELORD',
        description: 'Win 100 Around the Clock games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.hourglass_top),
        mode: 'aroundTheClock',
        milestoneTest: (ctx) => _modeWon(ctx, 'aroundTheClock') >= 100,
      ),
      Achievement(
        id: 'atc_marathon',
        name: 'MARATHON DARTS',
        description: 'Throw 1000 darts in Around the Clock',
        tier: AchievementTier.silver,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.directions_run),
        mode: 'aroundTheClock',
        milestoneTest: (ctx) => _modeCounter(ctx, 'aroundTheClock', 'totalDarts') >= 1000,
      ),

      // ===================== KILLER =====================
      Achievement(
        id: 'kil_survivor',
        name: 'SURVIVOR',
        description: 'Win your first Killer game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.shield),
        mode: 'killer',
        milestoneTest: (ctx) => _modeWon(ctx, 'killer') >= 1,
      ),
      Achievement(
        id: 'kil_reaper',
        name: 'REAPER',
        description: 'Win 50 Killer games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.dangerous),
        mode: 'killer',
        milestoneTest: (ctx) => _modeWon(ctx, 'killer') >= 50,
      ),
      Achievement(
        id: 'kil_executioner',
        name: 'EXECUTIONER',
        description: 'Eliminate 50 players across your career',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.gpp_bad),
        mode: 'killer',
        milestoneTest: (ctx) => _modeCounter(ctx, 'killer', 'kills') >= 50,
      ),
      Achievement(
        id: 'kil_sniper',
        name: 'CHIP SHOT',
        description: 'Land 50 hits on opponents',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.my_location),
        mode: 'killer',
        milestoneTest: (ctx) => _modeCounter(ctx, 'killer', 'attacksDealt') >= 50,
      ),
      Achievement(
        id: 'kil_killing_spree',
        name: 'KILLING SPREE',
        description: 'Eliminate 3+ players in a single turn',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.local_fire_department),
        mode: 'killer',
        event: AchievementEvent.multiKill,
      ),

      // ===================== SHANGHAI =====================
      Achievement(
        id: 'sha_first_blood',
        name: 'SHANGHAI ROOKIE',
        description: 'Win your first Shanghai game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.temple_buddhist),
        mode: 'shanghai',
        milestoneTest: (ctx) => _modeWon(ctx, 'shanghai') >= 1,
      ),
      Achievement(
        id: 'sha_legend',
        name: 'SHANGHAI LEGEND',
        description: 'Play 100 Shanghai games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.temple_hindu),
        mode: 'shanghai',
        milestoneTest: (ctx) => _modePlayed(ctx, 'shanghai') >= 100,
      ),
      Achievement(
        id: 'sha_serial_winner',
        name: 'SERIAL CHAMP',
        description: 'Win 50 Shanghai games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.emoji_events),
        mode: 'shanghai',
        milestoneTest: (ctx) => _modeWon(ctx, 'shanghai') >= 50,
      ),
      Achievement(
        id: 'sha_instant',
        name: 'INSTANT SHANGHAI',
        description: 'Win by hitting single, double and treble in one turn',
        tier: AchievementTier.gold,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.flash_on),
        mode: 'shanghai',
        event: AchievementEvent.instantShanghai,
      ),

      // ===================== SPLITSCORE =====================
      Achievement(
        id: 'spl_first_win',
        name: 'SPLIT DECISION',
        description: 'Win your first Splitscore game',
        tier: AchievementTier.bronze,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.call_split),
        mode: 'halveIt',
        milestoneTest: (ctx) => _modeWon(ctx, 'halveIt') >= 1,
      ),
      Achievement(
        id: 'spl_legend',
        name: 'SPLITSCORE LEGEND',
        description: 'Play 100 Splitscore games',
        tier: AchievementTier.gold,
        category: AchievementCategory.milestone,
        glyph: _g(Icons.account_tree),
        mode: 'halveIt',
        milestoneTest: (ctx) => _modePlayed(ctx, 'halveIt') >= 100,
      ),
      Achievement(
        id: 'spl_hit_machine',
        name: 'HIT MACHINE',
        description: 'Hit 200 target rounds across your career',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.gps_fixed),
        mode: 'halveIt',
        milestoneTest: (ctx) => _modeCounter(ctx, 'halveIt', 'roundsHit') >= 200,
      ),
      Achievement(
        id: 'spl_clutch_save',
        name: 'CLUTCH SAVE',
        description: 'Avoid a halving with your final dart',
        tier: AchievementTier.silver,
        category: AchievementCategory.scoring,
        glyph: _g(Icons.health_and_safety),
        mode: 'halveIt',
        event: AchievementEvent.clutchSave,
      ),
    ];

List<Achievement>? _cache;

/// The catalog (built once, cached).
List<Achievement> get achievementCatalog => _cache ??= _build();
