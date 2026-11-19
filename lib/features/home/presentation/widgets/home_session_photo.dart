import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';

/// Photo of the session under the title and date (L4b-D1): the thumbnail of
/// the first exercise of the hero session, [height] tall, cover. L4b-I9: it
/// bleeds edge to edge (no side margin, square corners), so the parent must
/// give it the full screen width.
///
/// While it loads, a raised box of the same size (no spinner). Without a URL,
/// on a load error or with an expired signed URL the slot and the gap above
/// it collapse to nothing: no icon, no exception. Decorative: excluded from
/// semantics. URLs are not renewed here.
class HomeSessionPhoto extends StatelessWidget {
  const HomeSessionPhoto({super.key, required this.url});

  static const double height = 200;

  @visibleForTesting
  static const placeholderKey = ValueKey('home-session-photo-placeholder');

  @visibleForTesting
  static const imageKey = ValueKey('home-session-photo-image');

  final String url;

  Widget _frame(Widget child) => Padding(
    padding: const EdgeInsets.only(top: ExomSpacing.lg),
    child: SizedBox(height: height, width: double.infinity, child: child),
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          return CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: PerformanceProfile.imageCacheWidth(context, width),
            imageBuilder: (context, provider) => _frame(
              Image(key: imageKey, image: provider, fit: BoxFit.cover),
            ),
            placeholder: (context, url) => _frame(
              ColoredBox(
                key: placeholderKey,
                color: context.exomPalette.surfaceElevated,
              ),
            ),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
