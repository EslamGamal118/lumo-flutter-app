import 'package:flutter/material.dart';
import '../../../shared/providers/auth_provider.dart';
import '../view_model/community_view_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar_widget.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _contentController;
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    
    final viewModel = context.read<CommunityViewModel>();
    if (viewModel.isLoading) {
      setState(() => _isSubmitting = false);
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _isSubmitting = false);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    
    final success = await viewModel.createPost(
      content: content,
      imagePath: _selectedImage?.path,
      currentUserName: user?.name ?? '',
      currentUserAvatar: user?.avatarUrl,
      currentUserId: user?.id,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.errorMessage ?? 'فشل إنشاء المنشور'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final viewModel = context.watch<CommunityViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء منشور'),
        actions: [
          if (viewModel.isLoading || _isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _handleSubmit,
              child: Text(
                l10n.post,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  imageUrl: user?.avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  user?.name ?? '',
                  style:
                      AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'ماذا يدور في ذهنك؟',
                border: InputBorder.none,
                hintStyle: AppTextStyles.body
                    .copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.image_outlined, color: AppColors.primary),
              title: const Text('إضافة صورة'),
              onTap: _pickImage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
