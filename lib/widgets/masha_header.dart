import 'package:flutter/material.dart';

/// Banner at the top of Home (Masha & Bear picture + message).
class MashaHeader extends StatelessWidget {
  final String subtitle;
  const MashaHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.secondary, cs.primary])),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/masha_bear.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              errorBuilder: (_, __, ___) => const SizedBox()),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black.withValues(alpha: 0.70), Colors.black.withValues(alpha: 0.05)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Masha says:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 190,
                    child: Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary, width: 4)),
              child: ClipOval(
                child: Image.asset('assets/images/masha_face.jpg',
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('🐻🍯', style: TextStyle(fontSize: 64))),
              ),
            ),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
