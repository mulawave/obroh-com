import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../services/api_service.dart';

class AvatarCircle extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;

  const AvatarCircle({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final url = ApiService.imageUrl(imageUrl);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ObrohColors.gold400.withValues(alpha: 0.2),
            ObrohColors.gold600.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(color: ObrohColors.gold400.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => _buildInitials(),
              errorWidget: (_, _, _) => _buildInitials(),
            )
          : _buildInitials(),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: ObrohColors.gold400,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
