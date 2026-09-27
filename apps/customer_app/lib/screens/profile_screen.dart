import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:image_picker/image_picker.dart';
import 'saved_screen.dart';
import 'chatbot_screen.dart';


class CustomerProfileScreen extends StatefulWidget {
  final AppUser? user;
  final AuthController auth;
  final VoidCallback onOrders;
  const CustomerProfileScreen(
      {super.key,
      required this.user,
      required this.auth,
      required this.onOrders});
  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _busy = false;
  String? _localPhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchFirestoreAvatar();
  }

  static const List<Map<String, String>> _presetAvatars = [
    {'name': 'Alex', 'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200'},
    {'name': 'Liam', 'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200'},
    {'name': 'Sophia', 'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200'},
    {'name': 'Ethan', 'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200'},
    {'name': 'Emma', 'url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200'},
    {'name': 'Olivia', 'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200'},
  ];

  Future<void> _fetchFirestoreAvatar() async {
    try {
      String? uid = widget.user?.uid;
      try {
        uid ??= FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      uid ??= 'customer_1';

      try {
        final prefs = await PreferencesService.getInstance();
        final cached = prefs.getUserAvatar(uid);
        if (cached != null && cached.isNotEmpty && mounted && _localPhotoUrl == null) {
          setState(() => _localPhotoUrl = cached);
        }
      } catch (_) {}

      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (mounted && doc.exists) {
          final data = doc.data();
          final avatar = (data?['photoUrl'] ?? data?['avatarUrl']) as String?;
          if (avatar != null && avatar.isNotEmpty) {
            if (mounted) setState(() => _localPhotoUrl = avatar);
            final prefs = await PreferencesService.getInstance();
            await prefs.setUserAvatar(uid, avatar);
          }
        }
      } catch (_) {}
    } catch (_) {}
  }

  String? get _photo {
    if (_localPhotoUrl != null && _localPhotoUrl!.isNotEmpty) return _localPhotoUrl;
    try {
      final authPhoto = FirebaseAuth.instance.currentUser?.photoURL;
      if (authPhoto != null && authPhoto.isNotEmpty) return authPhoto;
    } catch (_) {}
    return null;
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _applyAvatarUrl(String downloadUrl) async {
    setState(() => _busy = true);
    final targetUid = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'customer_1';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://'))) {
        try {
          await user.updatePhotoURL(downloadUrl);
        } catch (_) {}
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(targetUid).set(
          {'photoUrl': downloadUrl, 'avatarUrl': downloadUrl},
          SetOptions(merge: true),
        );
      } catch (_) {}

      try {
        final prefs = await PreferencesService.getInstance();
        await prefs.setUserAvatar(targetUid, downloadUrl);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _localPhotoUrl = downloadUrl;
        });
      }
      _message('Profile photo updated.');
    } catch (_) {
      _message('Could not update profile photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    final pickedPreset = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: HhColors.text.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'Change Profile Photo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: HhColors.sageLight,
                        child: Icon(Icons.photo_library_outlined, color: HhColors.primary, size: 20),
                      ),
                      title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.pop(ctx, 'GALLERY'),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: HhColors.sageLight,
                        child: Icon(Icons.camera_alt_outlined, color: HhColors.primary, size: 20),
                      ),
                      title: const Text('Take a photo', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.pop(ctx, 'CAMERA'),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Text(
                        'Or pick an avatar preset',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: HhColors.muted),
                      ),
                    ),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetAvatars.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final preset = _presetAvatars[index];
                          return GestureDetector(
                            onTap: () => Navigator.pop(ctx, preset['url']),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CachedNetworkImage(
                                      imageUrl: preset['url']!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const ColoredBox(color: HhColors.sageLight),
                                      errorWidget: (_, __, ___) => const ColoredBox(
                                        color: HhColors.sageLight,
                                        child: Icon(Icons.person, color: HhColors.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preset['name']!,
                                  style: const TextStyle(fontSize: 11, color: HhColors.muted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ));

    if (pickedPreset == null || !mounted) return;

    if (pickedPreset != 'GALLERY' && pickedPreset != 'CAMERA') {
      /* User tapped one of the presets directly */
      await _applyAvatarUrl(pickedPreset);
      return;
    }

    final source = pickedPreset == 'CAMERA' ? ImageSource.camera : ImageSource.gallery;

    setState(() => _busy = true);
    Reference? uploaded;
    try {
      final photo = await ImagePicker().pickImage(
          source: source, maxWidth: 400, maxHeight: 400, imageQuality: 70);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _message('Choose an image smaller than 5 MB.');
        return;
      }
      final targetUid = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'customer_1';
      final lower = photo.name.toLowerCase();
      final type = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      String? downloadUrl;
      try {
        final ref = FirebaseStorage.instance
            .ref('avatars/$targetUid/${DateTime.now().microsecondsSinceEpoch}');
        await ref.putData(bytes, SettableMetadata(contentType: type));
        uploaded = ref;
        downloadUrl = await ref.getDownloadURL();
        uploaded = null;
      } catch (_) {
        /* If cloud storage upload fails, encode optimized avatar as base64 data URI */
        final base64String = base64Encode(bytes);
        downloadUrl = 'data:$type;base64,$base64String';
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://'))) {
        try {
          await user.updatePhotoURL(downloadUrl);
        } catch (_) {}
      }

      try {
        if (downloadUrl.isNotEmpty) {
          if (user != null) {
            await user.updatePhotoURL(downloadUrl);
          }
          await FirebaseFirestore.instance.collection('users').doc(targetUid).set(
            {'photoUrl': downloadUrl, 'avatarUrl': downloadUrl},
            SetOptions(merge: true),
          );
        }
        await FirebaseFirestore.instance.collection('users').doc(targetUid).set(
          {'photoUrl': downloadUrl, 'avatarUrl': downloadUrl},
          SetOptions(merge: true),
        );
      } catch (_) {}

      try {
        final prefs = await PreferencesService.getInstance();
        await prefs.setUserAvatar(targetUid, downloadUrl);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _localPhotoUrl = downloadUrl;
        });
      }
      _message('Profile photo updated.');
    } catch (_) {
      if (uploaded != null) {
        try {
          await uploaded.delete();
        } catch (_) {}
      }
      _message(
          'Could not update photo. Please check app permissions and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = widget.user?.email;
    if (email == null || email.isEmpty) return;
    final confirmed = await _confirm(
        'Reset password', 'Send a password reset link to $email?', 'Send link');
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _message('Reset link sent. Check your inbox and spam folder.');
    } catch (_) {
      _message('Could not send the reset link. Please try again later.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(title), content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(action)),
              ])) ??
      false;

  Future<void> _logout() async {
    if (!await _confirm('Sign out', 'Sign out of your account on this device?',
            'Sign out') ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.clearAuthCredentials();
      await widget.auth.logout();
    } catch (_) {
      _message('Could not sign out. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProfileEditSheet(user: widget.user!, auth: widget.auth));

  Widget _tile(
          IconData icon, String title, String subtitle, VoidCallback? action) =>
      ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: HhColors.primary, size: 22),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle,
                  style: const TextStyle(fontSize: 13, color: HhColors.muted))),
          trailing:
              action == null ? null : const Icon(Icons.chevron_right, size: 20),
          onTap: _busy ? null : action);
  Widget _group(List<Widget> children) => Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(children: children));

    Widget _buildAvatarWidget(String? photo) {
    if (photo == null || photo.isEmpty) {
      return const ColoredBox(
        color: HhColors.sageLight,
        child: Icon(Icons.person_outline, size: 42, color: HhColors.primary),
      );
    }
    if (photo.startsWith("data:image")) {
      try {
        final commaIndex = photo.indexOf(",");
        final base64Content =
            commaIndex != -1 ? photo.substring(commaIndex + 1) : photo;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: HhColors.sageLight,
            child: Icon(Icons.person_outline, size: 42, color: HhColors.primary),
          ),
        );
      } catch (_) {
        return const ColoredBox(
          color: HhColors.sageLight,
          child: Icon(Icons.person_outline, size: 42, color: HhColors.primary),
        );
      }
    }
    return CachedNetworkImage(
      imageUrl: photo,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(
        color: HhColors.sageLight,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HhColors.primary,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: HhColors.sageLight,
        child: Icon(Icons.person_outline, size: 42, color: HhColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null) {
      return const Center(child: Text('Sign in to view your profile.'));
    }
    return Scaffold(
        backgroundColor: HhColors.bg,
        appBar: AppBar(
            title: const Text('My profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _group([
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Semantics(
                          label: 'Change profile photo',
                          button: true,
                          child: InkWell(
                              onTap: _busy ? null : _changePhoto,
                              borderRadius: BorderRadius.circular(48),
                              child: Stack(children: [
                                ClipOval(
                                    child: SizedBox(
                                        width: 88,
                                        height: 88,
                                        child: _buildAvatarWidget(_photo))),
                                Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: HhColors.primary,
                                        child: _busy
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Icon(Icons.camera_alt,
                                                size: 16,
                                                color: Colors.white))),
                              ]))),
                      TextButton(
                          onPressed: _busy ? null : _changePhoto,
                          child: const Text('Change photo',
                              style: TextStyle(fontSize: 13))),
                      Text(user.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(user.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: HhColors.muted)),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                              onPressed: _busy ? null : _edit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit profile'))),
                    ]))
              ]),
              const SizedBox(height: 20),
              const Text('Personal information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _group([
                _tile(
                    Icons.phone_outlined,
                    'Phone number',
                    user.phone.isEmpty ? 'Add your phone number' : user.phone,
                    _edit),
                const Divider(height: 1, indent: 54),
                _tile(
                    Icons.location_on_outlined,
                    'Contact address',
                    user.address.isEmpty ? 'Add your address' : user.address,
                    _edit),
              ]),
              const SizedBox(height: 20),
              const Text('Your account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _group([
                _tile(Icons.receipt_long_outlined, 'My orders',
                    'Track pickups and view order history', widget.onOrders),
                const Divider(height: 1, indent: 54),
                _tile(
                    Icons.favorite_border_rounded,
                    'My wishlist',
                    'Your favorite produce, saved for later',
                    () => openSavedItems(context)),
                const Divider(height: 1, indent: 54),
                _tile(
                    Icons.agriculture_outlined,
                    'Following',
                    'Keep your favorite farms close',
                    () => openSavedItems(context, initialTab: 1)),
                const Divider(height: 1, indent: 54),
                _tile(
                    Icons.smart_toy_outlined,
                    'AI Farm Assistant',
                    'Ask AI about produce nutrition, storage, and crops',
                    () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatbotScreen(),
                          ),
                        )),
                const Divider(height: 1, indent: 54),
                _tile(Icons.lock_outline, 'Reset password',
                    'Receive a secure link by email', _resetPassword),
              ]),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _logout,
                  icon: const Icon(Icons.logout, size: 20),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: HhColors.danger,
                      minimumSize: const Size.fromHeight(48)),
                  label: const Text('Sign out')),
            ]));
  }
}

class ProfileEditSheet extends StatefulWidget {
  final AppUser user;
  final AuthController auth;
  const ProfileEditSheet({super.key, required this.user, required this.auth});
  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _address = TextEditingController(text: widget.user.address);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await widget.auth.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim());
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } else {
      setState(() {
        _saving = false;
        _error = 'Could not save your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('Edit profile',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700))),
                              IconButton(
                                  tooltip: 'Close',
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: const Icon(Icons.close))
                            ]),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _name,
                                enabled: !_saving,
                                maxLength: 80,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    border: OutlineInputBorder()),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter your name'
                                    : null),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _phone,
                                enabled: !_saving,
                                maxLength: 25,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                    labelText: 'Phone number',
                                    border: OutlineInputBorder()),
                                validator: (v) =>
                                    RegExp(r'^\+?[0-9 ()-]{7,25}$')
                                                .hasMatch(v?.trim() ?? '') &&
                                            (v ?? '')
                                                    .replaceAll(
                                                        RegExp(r'\D'), '')
                                                    .length >=
                                                7
                                        ? null
                                        : 'Enter a valid phone number'),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _address,
                                enabled: !_saving,
                                maxLength: 250,
                                minLines: 2,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                    labelText: 'Contact address',
                                    border: OutlineInputBorder()),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter your address'
                                    : null),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: HhColors.danger))),
                            FilledButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Save changes')),
                          ]))))));
}
