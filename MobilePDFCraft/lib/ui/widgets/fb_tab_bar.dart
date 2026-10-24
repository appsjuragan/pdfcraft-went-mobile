import 'package:flutter/material.dart';
import '../theme/facebook_theme.dart';

class FbTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool hasActiveDoc;
  final bool activeDocNeedsSign;
  final int? signBadgeCount;

  const FbTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.hasActiveDoc = false,
    this.activeDocNeedsSign = false,
    this.signBadgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FacebookTheme.fbCardSurface,
        border: Border(
          bottom: BorderSide(color: FacebookTheme.fbCardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            index: 0,
            icon: Icons.feed_outlined,
            activeIcon: Icons.feed,
            label: 'Feed',
          ),
          _buildTabItem(
            index: 1,
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book,
            label: 'Studio',
            badgeCount: hasActiveDoc ? 1 : 0,
          ),
          _buildTabItem(
            index: 2,
            icon: Icons.draw_outlined,
            activeIcon: Icons.draw,
            label: 'Sign',
            badgeCount: signBadgeCount ?? 0,
            badgeDot: activeDocNeedsSign && (signBadgeCount == null || signBadgeCount! <= 0),
          ),
          _buildTabItem(
            index: 3,
            icon: Icons.verified_user_outlined,
            activeIcon: Icons.verified_user,
            label: 'Inspect',
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
    bool badgeDot = false,
  }) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? FacebookTheme.fbBlue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 26,
                    color: isSelected ? FacebookTheme.fbBlue : FacebookTheme.fbTextSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? FacebookTheme.fbBlue : FacebookTheme.fbTextSecondary,
                    ),
                  ),
                ],
              ),
              if (badgeDot)
                Positioned(
                  top: 2,
                  right: 24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: FacebookTheme.fbRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
