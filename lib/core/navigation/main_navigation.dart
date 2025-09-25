import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:marmooq/features/products/view/products_view.dart';
import 'package:marmooq/features/search/view/search_view.dart';
import 'package:marmooq/features/cart/view/cart_screen.dart';
import 'package:marmooq/features/auth/screens/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ProductsView(),
    const SearchView(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: FeatherIcons.home,
                    label: 'الرئيسية',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: FeatherIcons.search,
                    label: 'البحث',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: FeatherIcons.shoppingBag,
                    label: 'السلة',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: FeatherIcons.user,
                    label: 'الملف الشخصي',
                    index: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.brand : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.brand : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
