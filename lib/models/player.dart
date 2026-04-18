class Player {
  final String name;
  int score;
  final String? savedPlayerId;
  final String? avatarPath;

  Player({required this.name, required this.score, this.savedPlayerId, this.avatarPath});
}
