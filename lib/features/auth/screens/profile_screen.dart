import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopify_flutter/models/src/shopify_user/shopify_user.dart';
import 'package:traincode/features/auth/bloc/auth_state.dart';
import 'package:traincode/features/auth/screens/login_screen.dart';

import '../bloc/auth_bloc.dart';

/// Profile screen for authenticated users
class ProfileScreen extends StatefulWidget {
  /// Route name for navigation
  static const String routeName = '/profile';

  /// Constructor
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showDeleteConfirmation = false;

  void _signOut() {
    context.read<AuthBloc>().add(AuthSignOut());
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  void _showDeleteAccountDialog() {
    setState(() {
      _showDeleteConfirmation = true;
    });
  }

  void _cancelDeleteAccount() {
    setState(() {
      _showDeleteConfirmation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.unauthenticated) {
            Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          }
          if (state.hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'An error occurred'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.user == null) {
            return const Center(child: Text('User information not available'));
          }

          return _buildProfileContent(state.user!);
        },
      ),
    );
  }

  Widget _buildProfileContent(ShopifyUser user) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 24),
              _buildSectionTitle('Account Information'),
              _buildInfoItem('Email', user.email!),
              if (user.phone != null) _buildInfoItem('Phone', user.phone!),
              const SizedBox(height: 24),
              _buildSectionTitle('Account Actions'),
              _buildActionButton('Change Password', Icons.lock_outline, () {
                // Navigate to change password screen
              }),
              _buildActionButton(
                'Delete Account',
                Icons.delete_outline,
                _showDeleteAccountDialog,
                isDestructive: true,
              ),
            ],
          ),
        ),
        if (_showDeleteConfirmation) _buildDeleteConfirmationDialog(),
      ],
    );
  }

  Widget _buildProfileHeader(ShopifyUser user) {
    final String displayName = [
      user.firstName ?? '',
      user.lastName ?? '',
    ].where((name) => name.isNotEmpty).join(' ');

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              displayName.isNotEmpty
                  ? displayName.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 40, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName.isNotEmpty ? displayName : 'Shopify Customer',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            user.email!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDestructive ? Colors.red.shade200 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmationDialog() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _cancelDeleteAccount,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
