import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'onboarding_progress_indicator.dart';
import 'onboarding_step_layout.dart';

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
              leading: const Icon(ExomIcons.camera),
              title: Text(l10n.feedbackFromCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(ExomIcons.gallery),
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
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final fieldStyle = TextStyle(color: palette.textPrimary);
    final birthDate = _birthDate;

    return Form(
      key: _formKey,
      child: OnboardingStepLayout(
        footer: OnboardingStepActions(
          primaryKey: const Key('onboarding-basics-next'),
          primaryLabel: l10n.onboardingNextButton,
          onPrimary: _submit,
          quietLabel: l10n.onboardingSkipButton,
          onQuiet: widget.onSkip,
        ),
        children: [
          OnboardingStepHeading(
            step: 1,
            total: 4,
            first: l10n.onboardingBasicsHeadlineFirst,
            second: l10n.onboardingBasicsHeadlineSecond,
          ),
          const SizedBox(height: ExomSpacing.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kOnboardingSidePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Avatar(
                      localPath: _localAvatarPath,
                      url: widget.initialAvatarUrl,
                      uploading: widget.avatarUploading,
                      onTap: _pickImage,
                    ),
                    const SizedBox(width: ExomSpacing.xl),
                    Expanded(
                      child: Text(
                        l10n.onboardingAvatarLabel,
                        style: onboardingStrongStyle(context),
                      ),
                    ),
                  ],
                ),
                if (widget.avatarUploading) ...[
                  const SizedBox(height: ExomSpacing.md),
                  const ExomOperationBar(),
                ],
                const SizedBox(height: ExomSpacing.xxl),
                TextFormField(
                  key: const Key('onboarding-first-name'),
                  controller: _firstNameController,
                  style: fieldStyle,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingFirstNameLabel,
                  ),
                  errorBuilder: onboardingFieldError,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.onboardingFirstNameRequired
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: ExomSpacing.lg),
                TextFormField(
                  key: const Key('onboarding-last-name'),
                  controller: _lastNameController,
                  style: fieldStyle,
                  decoration: InputDecoration(
                    labelText: l10n.onboardingLastNameLabel,
                  ),
                  errorBuilder: onboardingFieldError,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.onboardingLastNameRequired
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: ExomSpacing.lg),
                InkWell(
                  key: const Key('onboarding-birth-date'),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.onboardingBirthDateLabel,
                      suffixIcon: Icon(
                        ExomIcons.calendar,
                        color: palette.textSecondary,
                      ),
                    ),
                    child: Text(
                      birthDate != null
                          ? '${birthDate.day.toString().padLeft(2, '0')}/'
                                '${birthDate.month.toString().padLeft(2, '0')}/'
                                '${birthDate.year}'
                          : '',
                      style: fieldStyle.copyWith(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square avatar (sketch `.x-av`, 72) with the camera badge, as in Perfil:
/// the picked file, else the saved photo, else the profile icon. While the
/// photo uploads the badge goes away and taps are ignored.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.localPath,
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  final String? localPath;
  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  static const double _size = 72;
  static const double _badge = 24;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final path = localPath;
    final remote = url;
    final ImageProvider? image = path != null
        ? FileImage(File(path))
        : (remote != null ? NetworkImage(remote) : null);
    return Semantics(
      button: true,
      enabled: !uploading,
      label: AppLocalizations.of(context).profileChangePhotoA11y,
      excludeSemantics: true,
      onTap: uploading ? null : onTap,
      child: GestureDetector(
        key: const Key('onboarding-avatar'),
        onTap: uploading ? null : onTap,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    border: Border.all(
                      color: palette.borderSoft,
                      width: ExomRule.hairline,
                    ),
                    image: image == null
                        ? null
                        : DecorationImage(image: image, fit: BoxFit.cover),
                  ),
                  child: image == null
                      ? Icon(
                          ExomIcons.profile,
                          size: 32,
                          color: palette.textPrimary,
                        )
                      : null,
                ),
              ),
              if (!uploading)
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: _badge,
                    height: _badge,
                    child: ColoredBox(
                      color: palette.textPrimary,
                      child: Icon(
                        ExomIcons.camera,
                        size: 14,
                        color: palette.background,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
