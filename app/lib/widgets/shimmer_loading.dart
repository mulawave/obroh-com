import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ObrohColors.obsidian800,
      highlightColor: ObrohColors.obsidian700,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ObrohColors.obsidian800,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
