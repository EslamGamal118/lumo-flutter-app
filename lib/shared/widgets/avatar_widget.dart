import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final String? name;
  final double size;
  final VoidCallback? onTap;
  final bool showOnlineIndicator;
  final bool isOnline;
  final IconData? fallbackIcon;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.name,
    this.size = 40,
    this.onTap,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.cardColor,
              border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildAvatarBody(context),
          ),
          if (showOnlineIndicator)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppColors.online : AppColors.offline,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarBody(BuildContext context) {
    if (imageFile != null) {
      return Image.file(imageFile!, fit: BoxFit.cover);
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      String resolvedUrl = imageUrl!;

      // If the backend returns localhost URLs, rewrite them
      if (resolvedUrl.contains('localhost') || resolvedUrl.contains('127.0.0.1')) {
        resolvedUrl = resolvedUrl.replaceFirst(RegExp(r'http://(localhost|127\.0\.0\.1)(:\d+)?'), 'https://app2.clickexpress.delivery');
      }

      // If it's a relative API path
      if (!resolvedUrl.startsWith('http')) {
        if (!resolvedUrl.startsWith('/')) {
          resolvedUrl = '/$resolvedUrl';
        }
        resolvedUrl = 'https://app2.clickexpress.delivery$resolvedUrl';
      }

      // Network image
      if (resolvedUrl.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: resolvedUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              width: size,
              height: size,
            ),
          ),
          errorWidget: (context, url, error) => _buildPlaceholder(context),
        );
      }

      // Local file path (e.g. from camera/gallery picker)
      return Image.file(File(resolvedUrl), fit: BoxFit.cover);
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        fallbackIcon ?? Icons.person_rounded,
        color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
        size: size * 0.5,
      ),
    );
  }
}
