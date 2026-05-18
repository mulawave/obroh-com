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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final spacing = compact ? 3.0 : 5.0;
        final runSpacing = compact ? 3.0 : 5.0;

        final badges = <Widget>[
          _rectBadge(
            '12',
            'ACB',
            compact: compact,
            foreground: Colors.white,
            gradient: _badgeGradient,
          ),
          _rectBadge(
            'TEEN',
            'ESRB',
            compact: compact,
            background: Colors.white,
            foreground: Colors.black,
          ),
          _rectBadge(
            '!',
            'www.pegi.info',
            compact: compact,
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
            compact: compact,
            background: const Color(0xFF38BE6A),
            foreground: Colors.black,
          ),
          _rectBadge(
            '12+',
            'IARC',
            compact: compact,
            background: Colors.white,
            foreground: Colors.black,
          ),
          _circleBadge('12', compact: compact),
          _circleBadge('12', compact: compact),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                'CONTENT RATINGS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ObrohColors.gold400.withValues(alpha: 0.55),
                  fontSize: compact ? 7.5 : 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.9,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: runSpacing,
                children: badges,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _rectBadge(
    String label,
    String sublabel, {
    required bool compact,
    Color? background,
    Color foreground = Colors.white,
    bool isPegi = false,
    Gradient? gradient,
  }) {
    final surface = background ?? ObrohColors.gold500;
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 28 : 32),
      height: compact ? 28 : 30,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 5),
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
              fontSize: compact
                  ? (isPegi
                        ? 11.5
                        : label == 'TEEN'
                        ? 7.5
                        : 9)
                  : (isPegi
                        ? 13
                        : label == 'TEEN'
                        ? 8
                        : 10),
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
              fontSize: compact ? 4 : 4.5,
              fontWeight: FontWeight.w700,
              letterSpacing: isPegi ? 0 : 1.0,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBadge(String label, {required bool compact}) {
    return Container(
      width: compact ? 28 : 30,
      height: compact ? 28 : 30,
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
        style: TextStyle(
          color: ObrohColors.obsidian950,
          fontSize: compact ? 10.5 : 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
