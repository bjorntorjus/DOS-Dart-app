import 'package:flutter/material.dart';
import '../theme/dossedart_tokens.dart';

/// Arcade-track per-player accent cycle (WILDCARD standings/active card).
/// Yellow is reserved for leader/labels and red for danger — excluded.
const dossedartAccents = [
  DossedartTokens.cyan,
  DossedartTokens.magenta,
  DossedartTokens.green,
  DossedartTokens.purple,
  DossedartTokens.orange,
];

Color dossedartAccent(int index) =>
    dossedartAccents[index % dossedartAccents.length];
