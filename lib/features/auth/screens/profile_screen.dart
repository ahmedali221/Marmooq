import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/auth/bloc/auth_bloc.dart';
import 'package:marmooq/features/auth/bloc/auth_state.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(isTablet ? 12 : 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[700], size: isTablet ? 24 : 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Tajawal',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 8 : 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDesktop = screenSize.width > 1200;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StandardAppBar(
        backgroundColor: Colors.white,
        title: 'الملف الشخصي',
        onLeadingPressed: null,
        actions: [],
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.unauthenticated) {
            context.go('/login');
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (!state.isAuthenticated || state.user == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'يرجى تسجيل الدخول لعرض الملف الشخصي',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: isTablet ? 18 : 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final ShopifyUser user = state.user!;
          final String fullName = [
            user.firstName,
            user.lastName,
          ].where((e) => (e ?? '').isNotEmpty).join(' ');

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop
                        ? 800
                        : isTablet
                        ? 600
                        : double.infinity,
                  ),
                  child: Column(
                    children: [
                      // Header with profile info
                      Container(
                        padding: EdgeInsets.all(isTablet ? 32 : 20),
                        child: Column(
                          children: [
                            SizedBox(height: isTablet ? 32 : 20),
                            // Profile Image
                            Container(
                              width: isTablet ? 120 : 80,
                              height: isTablet ? 120 : 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.brand,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  ((user.firstName ?? '').isNotEmpty
                                          ? user.firstName!.substring(0, 1)
                                          : 'M') +
                                      ((user.lastName ?? '').isNotEmpty
                                          ? user.lastName!.substring(0, 1)
                                          : ''),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isTablet ? 36 : 28,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isTablet ? 24 : 16),
                            // User Name
                            Text(
                              fullName.isNotEmpty ? fullName : 'Mark Adam',
                              style: TextStyle(
                                fontSize: isTablet ? 28 : 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Email
                            Text(
                              user.email ?? 'sunny_koeipndag@hotmail.com',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 32 : 20),

                      // Menu Items
                      _buildMenuItem(
                        icon: FeatherIcons.user,
                        title:
                            'الاسم: ${fullName.isNotEmpty ? fullName : 'غير محدد'}',
                        onTap: () {
                          // Navigate to profile details
                        },
                        isTablet: isTablet,
                      ),
                      _buildMenuItem(
                        icon: FeatherIcons.mail,
                        title: 'البريد الإلكتروني: ${user.email ?? 'غير محدد'}',
                        onTap: () {
                          // Navigate to contact
                        },
                        isTablet: isTablet,
                      ),
                      _buildMenuItem(
                        icon: FeatherIcons.phone,
                        title: 'الهاتف: ${user.phone ?? 'غير محدد'}',
                        onTap: () {
                          // Navigate to phone settings
                        },
                        isTablet: isTablet,
                      ),

                      SizedBox(height: isTablet ? 60 : 40),

                      // Sign Out Button
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : 20,
                        ),
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            context.read<AuthBloc>().add(AuthSignOut());
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 20 : 16,
                            ),
                          ),
                          child: Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[600],
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 60 : 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
