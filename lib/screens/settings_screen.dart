import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'gateway_management_screen.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Profile Section
          _buildProfileSection(context),
          const Divider(height: 1),

          // Theme Section
          _buildThemeSection(context),
          const Divider(height: 1),

          // Gateway Management
          _buildMenuItem(
            context,
            icon: Icons.router,
            title: 'Quản lý Gateway',
            subtitle: 'Xem và quản lý các Gateway',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GatewayManagementScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),

          // About & Support
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: 'Về ứng dụng',
            subtitle: 'Thông tin và hỗ trợ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const Divider(height: 1),

          // Logout
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Đăng xuất',
            subtitle: 'Thoát khỏi tài khoản',
            textColor: Colors.red,
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final profileProvider = Provider.of<UserProfileProvider>(context);
    final authService = AuthService();
    final user = authService.currentUser;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: profileProvider.avatarUrl.isNotEmpty
            ? NetworkImage(profileProvider.avatarUrl)
            : null,
        child: profileProvider.avatarUrl.isEmpty
            ? Icon(Icons.person, size: 32, color: AppColors.primary)
            : null,
      ),
      title: Text(
        profileProvider.displayName.isNotEmpty
            ? profileProvider.displayName
            : 'Chưa đặt tên',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        user?.email ?? 'Không có email',
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
          );
        },
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ExpansionTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Giao diện'),
      subtitle: Text(_getThemeModeName(themeProvider.themeMode)),
      children: [
        RadioListTile<ThemeMode>(
          title: const Text('Sáng'),
          subtitle: const Text('Giao diện sáng'),
          value: ThemeMode.light,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Tối'),
          subtitle: const Text('Giao diện tối'),
          value: ThemeMode.dark,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Theo hệ thống'),
          subtitle: const Text('Tự động thay đổi theo cài đặt thiết bị'),
          value: ThemeMode.system,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Sáng';
      case ThemeMode.dark:
        return 'Tối';
      case ThemeMode.system:
        return 'Theo hệ thống';
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
