import 'package:flutter/material.dart';

import '../theme.dart';

class ContentRatingsStrip extends StatelessWidget {
  const ContentRatingsStrip({super.key});

  static const _badgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ObrohColors.gold200, ObrohColors.gold400, ObrohColors.gold600],
  );

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      _rectBadge(
        '12',
        'ACB',
        foreground: Colors.white,
        gradient: _badgeGradient,
      ),
      _rectBadge(
        'TEEN',
        'ESRB',
        background: Colors.white,
        foreground: Colors.black,
      ),
      _rectBadge(
        '!',
        'www.pegi.info',
        foreground: Colors.white,
        isPegi: true,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ObrohColors.gold300,
            ObrohColors.gold500,
            ObrohColors.gold600,
          ],
        ),
      ),
      _rectBadge(
        'USK 12',
        'Germany',
        background: const Color(0xFF38BE6A),
        foreground: Colors.black,
      ),
      _rectBadge(
        '12+',
        'IARC',
        background: Colors.white,
        foreground: Colors.black,
      ),
      _circleBadge('12'),
      _circleBadge('12'),
    ];

    return Column(
      children: [
        Text(
          'CONTENT RATINGS',
          style: TextStyle(
            color: ObrohColors.gold400.withValues(alpha: 0.55),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.9,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 5,
          runSpacing: 5,
          children: badges,
        ),
      ],
    );
  }

  Widget _rectBadge(
    String label,
    String sublabel, {
    Color? background,
    Color foreground = Colors.white,
    bool isPegi = false,
    Gradient? gradient,
  }) {
    final surface = background ?? ObrohColors.gold500;
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: gradient == null ? surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: foreground.withValues(
            alpha: surface == Colors.white ? 0.35 : 0.12,
          ),
          width: surface == Colors.white ? 1.0 : 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: isPegi
                  ? 13
                  : label == 'TEEN'
                  ? 8
                  : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: label == 'TEEN' ? 1.0 : 0,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sublabel,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.82),
              fontSize: 4.5,
              fontWeight: FontWeight.w700,
              letterSpacing: isPegi ? 0 : 1.0,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBadge(String label) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _badgeGradient,
        border: Border.all(
          color: ObrohColors.gold200.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: ObrohColors.obsidian950,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
