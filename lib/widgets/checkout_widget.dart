import 'package:flutter/material.dart';
import '../data/checkout_table.dart';

class CheckoutWidget extends StatelessWidget {
  final int remainingScore;
  final bool doubleOut;

  const CheckoutWidget({
    super.key,
    required this.remainingScore,
    required this.doubleOut,
  });

  @override
  Widget build(BuildContext context) {
    if (remainingScore > 180 || remainingScore < 2) return const SizedBox.shrink();

    String? checkout;
    if (doubleOut) {
      // Only show for scores with a known checkout (max 170 for double out)
      if (remainingScore > 170) return const SizedBox.shrink();
      checkout = checkoutTable[remainingScore];
    } else {
      // Straight out — any score up to 180 can be finished in 3 darts
      checkout = straightOutCheckout(remainingScore);
    }

    if (checkout == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber[600], size: 16),
          const SizedBox(width: 6),
          Text(
            checkout,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
