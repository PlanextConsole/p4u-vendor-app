import 'package:flutter/material.dart';

import 'app_card.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: .65);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: muted, fontSize: 12))),
              Icon(icon, size: 18, color: muted),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: const TextStyle(fontSize: 11, color: Colors.green)),
          ],
        ],
      ),
    );
  }
}
