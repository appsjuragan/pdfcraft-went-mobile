import 'package:flutter/material.dart';
import '../theme/facebook_theme.dart';

class FbAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onOpenTap;
  final VoidCallback? onCreateTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAddTap;
  final String engineStatus;
  final bool isNative;

  const FbAppBar({
    super.key,
    this.onOpenTap,
    this.onCreateTap,
    this.onSearchTap,
    this.onAddTap,
    required this.engineStatus,
    this.isNative = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FacebookTheme.fbCardSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Facebook Logo Style: "pdfcraft"
            const Text(
              'pdfcraft',
              style: TextStyle(
                color: FacebookTheme.fbBlue,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(width: 8),
            // Engine status indicator badge
            Tooltip(
              message: engineStatus,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FacebookTheme.fbBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FacebookTheme.fbBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isNative ? FacebookTheme.fbGreen : FacebookTheme.fbAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNative ? 'Core' : 'Dart',
                      style: const TextStyle(
                        color: FacebookTheme.fbBlueDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Facebook-style search icon
            if (onSearchTap != null) ...[
              _FbCircleButton(
                icon: Icons.search_rounded,
                tooltip: 'Search Documents',
                onTap: onSearchTap!,
              ),
              const SizedBox(width: 8),
            ],
            // Facebook-style round icon button for creating / add
            _FbCircleButton(
              icon: Icons.add,
              tooltip: 'Create New PDF',
              onTap: onAddTap ?? onCreateTap ?? () {},
            ),
            if (onOpenTap != null) ...[
              const SizedBox(width: 8),
              _FbCircleButton(
                icon: Icons.folder_open_outlined,
                tooltip: 'Open PDF File',
                onTap: onOpenTap!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FbCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FbCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFE4E6EB),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: FacebookTheme.fbTextPrimary),
          ),
        ),
      ),
    );
  }
}
