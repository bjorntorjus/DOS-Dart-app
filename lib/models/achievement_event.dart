/// In-game moments that can unlock an event-type achievement. Fired from the
/// same points in game screens that already trigger sound/meme. Expanded in the
/// per-mode phases; this is the starter set.
enum AchievementEvent {
  // X01
  score180,
  bigCheckout, // checkout >= 100
  bullFinish,
  // Cricket
  nineMarkTurn,
  // Shanghai
  instantShanghai,
  // Killer
  becameKiller,
  multiKill,
  // Splitscore
  clutchSave,
  // Cross-cutting / meme
  nice69,
  sixSeven,
  threeMisses,
}
