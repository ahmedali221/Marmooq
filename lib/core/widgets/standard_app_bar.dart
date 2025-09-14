import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:traincode/core/constants/app_colors.dart';

class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onLeadingPressed;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showLeading;
  final Color? backgroundColor;
  final double elevation;

  const StandardAppBar({
    Key? key,
    required this.title,
    this.onLeadingPressed,
    this.leadingIcon,
    this.actions,
    this.centerTitle = true,
    this.showLeading = true,
    this.backgroundColor,
    this.elevation = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
          fontSize: 22,
          color: Colors.black,
        ),
      ),
      backgroundColor: backgroundColor ?? AppColors.brand,
      elevation: elevation,
      centerTitle: centerTitle,
      leading: showLeading
          ? Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  leadingIcon ?? FeatherIcons.chevronLeft,
                  color: AppColors.brandDark,
                ),
                onPressed:
                    onLeadingPressed ?? () => Navigator.of(context).pop(),
              ),
            )
          : null,
      actions: actions != null
          ? [...actions!, const SizedBox(width: 16)]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Standardized action button for app bars
class StandardAppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const StandardAppBarAction({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.size = 20,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor ?? Colors.white, size: size),
      ),
    );
  }
}
