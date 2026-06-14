import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
import 'home_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final bool completeOnSave;

  const EditProfileScreen({super.key, this.completeOnSave = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _workController = TextEditingController();
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final TextEditingController _lifeQuoteController = TextEditingController();
  final List<_JourneyInput> _journeyInputs = [];

  String? _photoUrl;
  DateTime? _birthday;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _hasLoadedProfile = false;
  bool _isApplyingProfileData = false;
  bool _hasUserEditedProfileFields = false;
  String? _nameErrorText;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    _bioController.addListener(_markProfileEdited);
    _workController.addListener(_markProfileEdited);
    _familyController.addListener(_markProfileEdited);
    _goalController.addListener(_markProfileEdited);
    _interestsController.addListener(_markProfileEdited);
    _locationController.addListener(_markProfileEdited);
    _relationshipController.addListener(_markProfileEdited);
    _lifeQuoteController.addListener(_markProfileEdited);
    _loadProfile();
  }

  void _handleNameChanged() {
    _markProfileEdited();
    if (_nameErrorText != null && _nameController.text.trim().isNotEmpty) {
      setState(() {
        _nameErrorText = null;
      });
    }
  }

  void _markProfileEdited() {
    if (!_isApplyingProfileData) {
      _hasUserEditedProfileFields = true;
    }
  }

  void _setLoadedText(TextEditingController controller, dynamic value) {
    final text = (value ?? '').toString();
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _loadProfile() async {
    if (_hasLoadedProfile) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted || _hasLoadedProfile) return;

    final data = doc.data();
    if (data != null) {
      if (_hasUserEditedProfileFields) {
        _hasLoadedProfile = true;
        return;
      }

      _isApplyingProfileData = true;
      try {
        _setLoadedText(_nameController, data['username']);
        _setLoadedText(_bioController, data['bio']);
        _setLoadedText(_workController, data['work']);
        _setLoadedText(_familyController, data['family']);
        _setLoadedText(_goalController, data['goal']);
        _setLoadedText(_interestsController, data['interests']);
        _setLoadedText(_locationController, data['location']);
        _setLoadedText(_relationshipController, data['relationship']);
        _setLoadedText(_lifeQuoteController, data['lifeQuote']);
        _birthday = _parseBirthday(data['birthday']);
        _setJourneyInputs(data['lifeJourney']);
      } finally {
        _isApplyingProfileData = false;
      }

      setState(() {
        _photoUrl = data['photoUrl'] ?? '';
      });
    }

    _hasLoadedProfile = true;
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final file = File(picked.path);
      final imageUrl = await CloudinaryService.uploadImage(file);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'photoUrl': imageUrl,
        }, SetOptions(merge: true));
      }

      setState(() {
        _photoUrl = imageUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to upload image')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveChanges() async {
    if (widget.completeOnSave && _nameController.text.trim().isEmpty) {
      setState(() {
        _nameErrorText = 'Please enter your name.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'family': _familyController.text.trim(),
        'goal': _goalController.text.trim(),
        'interests': _interestsController.text.trim(),
        'location': _locationController.text.trim(),
        'relationship': _relationshipController.text.trim(),
        'birthday': _birthday == null ? '' : _birthdayStorageValue(_birthday!),
        'lifeQuote': _lifeQuoteController.text.trim(),
        'lifeJourney': _lifeJourneyPayload(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      if (widget.completeOnSave) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save profile')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatar(double size) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[100],
          backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
              ? NetworkImage(_photoUrl!)
              : null,
          child: (_photoUrl == null || _photoUrl!.isEmpty)
              ? Icon(Icons.person, size: size * 0.5, color: Colors.grey[500])
              : null,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: Colors.white,
            elevation: 2,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isUploadingImage ? null : _pickImage,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: _isUploadingImage
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey[700],
                        ),
                      )
                    : Icon(Icons.edit, size: 18, color: Colors.grey[700]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(title: label, helperText: helperText),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: label,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6D4CFF)),
            ),
            prefixIcon: Icon(icon, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  DateTime? _parseBirthday(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  String _birthdayStorageValue(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatBirthday(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null) return;

    setState(() {
      _birthday = picked;
    });
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(
          title: 'Birthday',
          helperText: 'Your birthday (optional)',
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickBirthday,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Birthday',
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6D4CFF)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: Colors.black54),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _birthday == null
                        ? 'Birthday'
                        : _formatBirthday(_birthday!),
                    style: TextStyle(
                      color: _birthday == null
                          ? Colors.black54
                          : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_birthday != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _birthday = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.black45,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear birthday',
                  )
                else
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.black45,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _setJourneyInputs(dynamic value) {
    for (final input in _journeyInputs) {
      input.dispose();
    }
    _journeyInputs.clear();

    if (value is List) {
      for (final item in value.whereType<Map>()) {
        final year = (item['year'] ?? '').toString().trim();
        final title = (item['title'] ?? '').toString().trim();
        if (year.isEmpty && title.isEmpty) continue;

        _journeyInputs.add(_JourneyInput(year: year, title: title));
      }
    }
  }

  List<Map<String, String>> _lifeJourneyPayload() {
    return _journeyInputs.map((input) {
      return {
        'year': input.yearController.text.trim(),
        'title': input.titleController.text.trim(),
      };
    }).where((item) {
      return item['year']!.isNotEmpty && item['title']!.isNotEmpty;
    }).toList();
  }

  void _addJourneyInput() {
    setState(() {
      _journeyInputs.add(_JourneyInput());
    });
  }

  void _removeJourneyInput(int index) {
    setState(() {
      final input = _journeyInputs.removeAt(index);
      input.dispose();
    });
  }

  Widget _buildJourneyEditor() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Life Journey',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addJourneyInput,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6D4CFF),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_journeyInputs.isEmpty)
            const Text(
              'No journey added yet',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            for (int index = 0; index < _journeyInputs.length; index++) ...[
              _buildJourneyInputRow(index),
              if (index != _journeyInputs.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildJourneyInputRow(int index) {
    final input = _journeyInputs[index];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: TextField(
            controller: input.yearController,
            keyboardType: TextInputType.number,
            decoration: _journeyInputDecoration('Year'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: input.titleController,
            decoration: _journeyInputDecoration('Title'),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => _removeJourneyInput(index),
          icon: const Icon(Icons.close, size: 18),
          color: Colors.black45,
          visualDensity: VisualDensity.compact,
          tooltip: 'Remove journey item',
        ),
      ],
    );
  }

  InputDecoration _journeyInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6D4CFF)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _workController.dispose();
    _familyController.dispose();
    _goalController.dispose();
    _interestsController.dispose();
    _locationController.dispose();
    _relationshipController.dispose();
    _lifeQuoteController.dispose();
    for (final input in _journeyInputs) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Minimal, clean white layout with centered avatar and modern fields
    return PopScope(
      canPop: !widget.completeOnSave,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.completeOnSave,
        leading: widget.completeOnSave
            ? null
            : const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 18.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // Centered avatar
                Center(
                  child: SizedBox(
                    height: 110,
                    width: 110,
                    child: _buildAvatar(110),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Tell your life story',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add the details that help people understand who you are.',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 18),

                // Name field (modern rounded)
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Name',
                    errorText: widget.completeOnSave ? _nameErrorText : null,
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6D4CFF)),
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.black54,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Bio field (multiline) — ensure text starts top-left and no overlapping icon
                TextField(
                  controller: _bioController,
                  minLines: 4,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Bio',
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6D4CFF)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _buildProfileField(
                  controller: _workController,
                  label: 'Work',
                  helperText: 'Your job, profession, or what you do every day',
                  icon: Icons.work_outline,
                ),

                const SizedBox(height: 16),

                _buildProfileField(
                  controller: _familyController,
                  label: 'Family',
                  helperText: 'Tell people a little about your family',
                  icon: Icons.family_restroom,
                ),

                const SizedBox(height: 16),

                _buildProfileField(
                  controller: _goalController,
                  label: 'Goal',
                  helperText: 'What are you currently working towards?',
                  icon: Icons.flag_outlined,
                ),

                const SizedBox(height: 16),

                _buildProfileField(
                  controller: _interestsController,
                  label: 'Interests',
                  helperText: 'Hobbies, passions, and things you enjoy',
                  icon: Icons.sports_soccer_outlined,
                ),

                const SizedBox(height: 16),

                _buildProfileField(
                  controller: _locationController,
                  label: 'Location',
                  helperText: 'Country, city, or place you live',
                  icon: Icons.location_on_outlined,
                ),

                const SizedBox(height: 16),

                _buildBirthdayField(),

                const SizedBox(height: 16),

                _buildProfileField(
                  controller: _relationshipController,
                  label: 'Relationship',
                  helperText: 'Optional relationship status',
                  icon: Icons.favorite_border,
                ),

                const SizedBox(height: 16),

                _buildProfileField(
                  controller: _lifeQuoteController,
                  label: 'Life Quote',
                  helperText: 'A quote or sentence that represents you',
                  icon: Icons.format_quote,
                ),

                const SizedBox(height: 12),

                _buildJourneyEditor(),

                const SizedBox(height: 20),

                // Save button (purple)
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _JourneyInput {
  final TextEditingController yearController;
  final TextEditingController titleController;

  _JourneyInput({String year = '', String title = ''})
    : yearController = TextEditingController(text: year),
      titleController = TextEditingController(text: title);

  void dispose() {
    yearController.dispose();
    titleController.dispose();
  }
}

class _FieldLabel extends StatelessWidget {
  final String title;
  final String helperText;

  const _FieldLabel({
    required this.title,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          helperText,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
