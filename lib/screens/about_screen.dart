import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Về ứng dụng'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // App Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'KAgri App',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Phiên bản 1.0.0 (Build 1)',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giới thiệu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'KAgri App là ứng dụng giám sát và quản lý nông nghiệp thông minh, '
                      'giúp theo dõi các thông số môi trường như nhiệt độ, độ ẩm, pH đất, '
                      'và điều khiển thiết bị tự động qua Gateway IoT.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Support Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.email, color: AppColors.primary),
                    title: const Text('Email hỗ trợ'),
                    subtitle: const Text('support@kagri.com'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchEmail('support@kagri.com'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.phone, color: AppColors.primary),
                    title: const Text('Hotline'),
                    subtitle: const Text('1900 xxxx'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchPhone('1900xxxx'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.language, color: AppColors.primary),
                    title: const Text('Website'),
                    subtitle: const Text('www.kagri.com'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchUrl('https://www.kagri.com'),
                  ),
                ],
              ),
            ),
          ),

          // Legal Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.privacy_tip, color: AppColors.primary),
                    title: const Text('Chính sách bảo mật'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchUrl('https://www.kagri.com/privacy'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.description, color: AppColors.primary),
                    title: const Text('Điều khoản sử dụng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _launchUrl('https://www.kagri.com/terms'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.code, color: AppColors.primary),
                    title: const Text('Giấy phép mã nguồn mở'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLicenses(context),
                  ),
                ],
              ),
            ),
          ),

          // Copyright
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '© 2024 KAgri. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=KAgri App Support',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'KAgri App',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.agriculture, size: 40, color: Colors.white),
      ),
      applicationLegalese: '© 2024 KAgri. All rights reserved.',
    );
  }
}
