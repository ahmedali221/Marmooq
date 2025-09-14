import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:traincode/core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/features/auth/bloc/auth_bloc.dart';
import 'package:traincode/features/auth/bloc/auth_state.dart';
import 'package:traincode/core/widgets/standard_app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Tajawal',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                  const Text(
                    'يرجى تسجيل الدخول لعرض الملف الشخصي',
                    style: TextStyle(fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'تسجيل الدخول',
                      style: TextStyle(fontFamily: 'Tajawal'),
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with profile info
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Profile Image
                        Container(
                          width: 80,
                          height: 80,
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // User Name
                        Text(
                          fullName.isNotEmpty ? fullName : 'Mark Adam',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Email
                        Text(
                          user.email ?? 'sunny_koeipndag@hotmail.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Menu Items
                  _buildMenuItem(
                    icon: FeatherIcons.user,
                    title:
                        'الاسم: ${fullName.isNotEmpty ? fullName : 'غير محدد'}',
                    onTap: () {
                      // Navigate to profile details
                    },
                  ),
                  _buildMenuItem(
                    icon: FeatherIcons.mail,
                    title: 'البريد الإلكتروني: ${user.email ?? 'غير محدد'}',
                    onTap: () {
                      // Navigate to contact
                    },
                  ),
                  _buildMenuItem(
                    icon: FeatherIcons.phone,
                    title: 'الهاتف: ${user.phone ?? 'غير محدد'}',
                    onTap: () {
                      // Navigate to phone settings
                    },
                  ),

                  const SizedBox(height: 40),

                  // Sign Out Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthSignOut());
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[600],
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
