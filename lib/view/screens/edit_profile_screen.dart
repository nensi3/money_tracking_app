import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:money_tracking_app/view/utils/app_colors.dart';
import 'package:money_tracking_app/view/utils/app_input_decorations.dart';
import 'package:money_tracking_app/view/widgets/app_gradient_background.dart';
import 'package:money_tracking_app/view/widgets/auth_form_card.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String _storedPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _storedPhotoUrl = (data['photoUrl'] ?? '').toString().trim();
      if (_storedPhotoUrl.isEmpty && (user.photoURL ?? '').isNotEmpty) {
        _storedPhotoUrl = user.photoURL!.trim();
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isUploadingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for profile photo upload to finish.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logged-in user found')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': user.email ?? '',
        'phone': _phoneController.text.trim(),
        'photoUrl': _storedPhotoUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logged-in user found')));
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final downloadUrl = await _pickAndUploadProfilePhoto(
        pickedFile: pickedFile,
        userId: user.uid,
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': downloadUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _storedPhotoUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is FirebaseException && e.code == 'object-not-found'
          ? 'Photo uploaded but download URL was denied/not found. Deploy correct Firebase Storage rules (in Storage tab, not Firestore) and try again.'
          : e is FirebaseException && e.code == 'permission-denied'
          ? 'Photo upload is denied by Firebase Storage rules. Ask admin to deploy storage.rules and try again.'
          : 'Failed to upload photo: $e';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<String> _pickAndUploadProfilePhoto({
    required XFile pickedFile,
    required String userId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _fileExtensionFromPath(pickedFile.path);
    final fileName = 'profile_pictures/$userId/$timestamp.$extension';
    final storageRef = FirebaseStorage.instance.ref().child(fileName);

    final uploadTask = storageRef.putFile(
      File(pickedFile.path),
      SettableMetadata(contentType: _contentTypeForExtension(extension)),
    );

    final snapshot = await uploadTask;

    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'upload-failed',
        message: 'Profile photo upload did not complete successfully.',
      );
    }

    // Give Storage a moment to propagate the uploaded object metadata.
    await Future.delayed(const Duration(seconds: 1));

    FirebaseException? lastException;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        return await storageRef.getDownloadURL();
      } on FirebaseException catch (e) {
        lastException = e;
        if (e.code != 'object-not-found' || attempt == 7) {
          rethrow;
        }
        // Storage propagation can lag briefly on some devices/networks.
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    throw lastException ??
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'unknown',
          message: 'Unable to get download URL after upload.',
        );
  }

  String _fileExtensionFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _removeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logged-in user found')));
      return;
    }

    try {
      setState(() => _isUploadingPhoto = true);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': '',
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _storedPhotoUrl = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove photo: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty);
  }

  Widget _buildAvatarPreview() {
    final showPhoto = _isValidHttpUrl(_storedPhotoUrl);

    if (showPhoto) {
      return ClipOval(
        child: Image.network(
          _storedPhotoUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(),
        ),
      );
    }

    return _buildInitialAvatar();
  }

  Widget _buildInitialAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B6EEA).withValues(alpha: 0.95),
            const Color(0xFF5DADE2).withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _nameController.text.trim().isEmpty
              ? 'U'
              : _nameController.text.trim().substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: AuthFormCard(
                maxWidth: 380,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 26,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Loading profile...',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: AuthFormCard(
                      padding: const EdgeInsets.all(22),
                      opacity: 0.8,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                        },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  tooltip: 'Back',
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Center(
                              child: Icon(
                                Icons.account_circle_rounded,
                                size: 64,
                                color: AppColors.walletAccent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              decoration: AppInputDecorations.auth(
                                label: 'Full Name',
                                prefix: Icons.person_outline,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: AppInputDecorations.auth(
                                label: 'Phone Number',
                                prefix: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profile Photo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(child: _buildAvatarPreview()),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          (_isSaving || _isUploadingPhoto)
                                          ? null
                                          : _changeProfilePhoto,
                                      icon: _isUploadingPhoto
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.photo_library_rounded,
                                            ),
                                      label: Text(
                                        _isUploadingPhoto
                                            ? 'Uploading...'
                                            : 'Change Profile Photo',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          (_isSaving || _isUploadingPhoto)
                                          ? null
                                          : _removeProfilePhoto,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      label: const Text('Use Initials Avatar'),
                                    ),
                                  ),
                                  if (!_isValidHttpUrl(_storedPhotoUrl))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'No valid profile photo found. Initials avatar is currently shown.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (_isSaving || _isUploadingPhoto)
                                    ? null
                                    : _saveProfile,
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Save Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
