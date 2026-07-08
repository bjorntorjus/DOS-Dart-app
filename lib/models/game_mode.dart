enum GameMode {
  x01,
  cricket,
  aroundTheClock,
  killer,
  halveIt,
  shanghai,
  gotcha,
}

extension GameModeLabel on GameMode {
  String get label {
    switch (this) {
      case GameMode.x01:
        return 'X01';
      case GameMode.cricket:
        return 'Cricket';
      case GameMode.aroundTheClock:
        return 'Around the Clock';
      case GameMode.killer:
        return 'Killer';
      case GameMode.halveIt:
        return 'Splitscore';
      case GameMode.shanghai:
        return 'Shanghai';
      case GameMode.gotcha:
        return 'Gotcha';
    }
  }
}

extension GameModeEmoji on GameMode {
  String get emoji {
    switch (this) {
      case GameMode.x01:
        return '💯';
      case GameMode.cricket:
        return '🎯';
      case GameMode.aroundTheClock:
        return '🕐';
      case GameMode.killer:
        return '🔪';
      case GameMode.halveIt:
        return '✂️';
      case GameMode.shanghai:
        return '🐉';
      case GameMode.gotcha:
        return '💀';
    }
  }
}
