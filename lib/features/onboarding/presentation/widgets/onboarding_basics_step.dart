import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';

class OnboardingBasicsStep extends StatefulWidget {
  const OnboardingBasicsStep({
    super.key,
    required this.initialData,
    required this.initialAvatarUrl,
    this.avatarUploading = false,
    required this.onNext,
    required this.onSkip,
    required this.onAvatarPicked,
  });

  final Map<String, dynamic> initialData;
  final String? initialAvatarUrl;
  final bool avatarUploading;
  final void Function(Map<String, dynamic> data) onNext;
  final VoidCallback onSkip;
  final void Function(String filePath) onAvatarPicked;

  @override
  State<OnboardingBasicsStep> createState() => _OnboardingBasicsStepState();
}

class _OnboardingBasicsStepState extends State<OnboardingBasicsStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  DateTime? _birthDate;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.initialData['first_name'] as String? ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.initialData['last_name'] as String? ?? '',
    );
    final birthStr = widget.initialData['birth_date'] as String?;
    if (birthStr != null) {
      _birthDate = DateTime.tryParse(birthStr);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.feedbackFromCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.feedbackFromGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    var selectedSource = source;
    while (mounted) {
      try {
        final picked = await ImagePicker().pickImage(source: selectedSource);
        if (picked == null || !mounted) return;
        setState(() => _localAvatarPath = picked.path);
        widget.onAvatarPicked(picked.path);
        return;
      } on Object catch (error) {
        if (!mounted) return;
        final action = await showMediaPickerErrorDialog(
          context,
          error,
          canUseGallery: selectedSource != ImageSource.gallery,
        );
        if (action == MediaPickerRecoveryAction.gallery) {
          selectedSource = ImageSource.gallery;
        } else if (action != MediaPickerRecoveryAction.retry) {
          return;
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 10),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{};
    if (_firstNameController.text.trim().isNotEmpty) {
      data['first_name'] = _firstNameController.text.trim();
    }
    if (_lastNameController.text.trim().isNotEmpty) {
      data['last_name'] = _lastNameController.text.trim();
    }
    if (_birthDate != null) {
      data['birth_date'] = _birthDate!.toIso8601String();
    }
    widget.onNext(data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    final avatarFile = _localAvatarPath != null
        ? File(_localAvatarPath!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(24),
                  borderRadius: 28,
                  elevated: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.onboardingBasicsTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: GestureDetector(
                          onTap: widget.avatarUploading ? null : _pickImage,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: palette.glassBackground,
                                backgroundImage: avatarFile != null
                                    ? FileImage(avatarFile)
                                    : (widget.initialAvatarUrl != null
                                              ? NetworkImage(
                                                  widget.initialAvatarUrl!,
                                                )
                                              : null)
                                          as ImageProvider?,
                                child:
                                    (avatarFile == null &&
                                        widget.initialAvatarUrl == null)
                                    ? Icon(
                                        Icons.person,
                                        color: palette.textDisabled,
                                        size: 40,
                                      )
                                    : null,
                              ),
                              if (widget.avatarUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: palette.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: palette.primary.withValues(
                                            alpha: 0.22,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                          spreadRadius: -6,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: palette.onPrimary,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          l10n.onboardingAvatarLabel,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: l10n.onboardingFirstNameLabel,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.onboardingFirstNameRequired
                            : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: l10n.onboardingLastNameLabel,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.onboardingLastNameRequired
                            : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.onboardingBirthDateLabel,
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                          ),
                          child: Text(
                            _birthDate != null
                                ? '${_birthDate!.day.toString().padLeft(2, '0')}/'
                                      '${_birthDate!.month.toString().padLeft(2, '0')}/'
                                      '${_birthDate!.year}'
                                : '',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StepButtons(onNext: _submit, onSkip: widget.onSkip),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StepButtons extends StatelessWidget {
  const _StepButtons({required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onNext,
            child: Text(l10n.onboardingNextButton),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              l10n.onboardingSkipButton,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
