enum GameMode {
  x01,
  cricket,
  aroundTheClock,
  killer,
  halveIt,
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
        return 'Halve It';
    }
  }
}
