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

  void _fetchFirestoreAvatar() {
    final uid = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted && doc.exists) {
          final data = doc.data();
          final avatar = (data?['photoUrl'] ?? data?['avatarUrl']) as String?;
          if (avatar != null && avatar.isNotEmpty && _localPhotoUrl == null) {
            setState(() => _localPhotoUrl = avatar);
          }
        }
      }).catchError((_) {});
    }
  }

  String? get _photo =>
      _localPhotoUrl ?? FirebaseAuth.instance.currentUser?.photoURL;

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Change profile photo',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery)),
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera)),
            ])));
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    Reference? uploaded;
    try {
      final photo = await ImagePicker().pickImage(
          source: source, maxWidth: 512, maxHeight: 512, imageQuality: 75);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _message('Choose an image smaller than 5 MB.');
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Signed out');
      }
      final lower = photo.name.toLowerCase();
      final type = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      String? downloadUrl;
      try {
        final ref = FirebaseStorage.instance
            .ref('avatars/${user.uid}/${DateTime.now().microsecondsSinceEpoch}');
        await ref.putData(bytes, SettableMetadata(contentType: type));
        uploaded = ref;
        downloadUrl = await ref.getDownloadURL();
        uploaded = null;
      } catch (_) {
        /* If cloud storage upload fails, encode optimized avatar as base64 data URI */
        final base64String = base64Encode(bytes);
        downloadUrl = 'data:$type;base64,$base64String';
      }

      if (downloadUrl != null) {
        await user.updatePhotoURL(downloadUrl);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'photoUrl': downloadUrl, 'avatarUrl': downloadUrl},
          SetOptions(merge: true),
        );
        if (mounted) {
          setState(() {
            _localPhotoUrl = downloadUrl;
          });
        }
        _message('Profile photo updated.');
      }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
