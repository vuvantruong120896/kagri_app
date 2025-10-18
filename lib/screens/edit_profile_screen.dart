import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _avatarController;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    _nameController = TextEditingController(text: profile.displayName);
    _avatarController = TextEditingController(text: profile.avatarUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Preview
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: _avatarController.text.isNotEmpty
                          ? NetworkImage(_avatarController.text)
                          : null,
                      child: _avatarController.text.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                          onPressed: _showAvatarOptions,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Display Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  hintText: 'Nhập tên của bạn',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Avatar URL Field
              TextFormField(
                controller: _avatarController,
                decoration: InputDecoration(
                  labelText: 'URL ảnh đại diện',
                  hintText: 'https://example.com/avatar.jpg',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (value) {
                  setState(() {}); // Update avatar preview
                },
              ),
              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ảnh đại diện sẽ được tải từ URL. Hãy đảm bảo URL hợp lệ.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Nhập URL ảnh'),
              onTap: () {
                Navigator.pop(context);
                _showUrlDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xóa ảnh đại diện'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _avatarController.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlDialog() {
    final urlController = TextEditingController(text: _avatarController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL ảnh đại diện'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://example.com/avatar.jpg',
            labelText: 'URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _avatarController.text = urlController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final profileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: false,
      );

      await profileProvider.updateDisplayName(_nameController.text.trim());
      await profileProvider.updateAvatarUrl(_avatarController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu thông tin hồ sơ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
