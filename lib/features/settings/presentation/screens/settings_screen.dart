import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/backup_service.dart';
import '../../../notes/data/database.dart';
import '../../../notes/presentation/providers/notes_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keepUnlockedDuration = ref.watch(keepUnlockedDurationProvider);
    final keepUnlockedActive = ref.watch(keepUnlockedActiveProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('App Unlock (Fingerprint / Password)', theme),
          _buildAppUnlockInfoCard(theme),
          _buildKeepUnlockedSection(context, theme, keepUnlockedDuration, keepUnlockedActive),
          _buildChangePasswordSection(context, theme),
          _buildLockNowSection(context, theme),
          _buildSectionTitle('Backup Password', theme),
          _buildBackupPasswordInfoCard(theme),
          _buildBackupSection(context, theme),
          _buildSectionTitle('About', theme),
          _buildAboutSection(context, theme),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Info card explaining that app unlock is local/device-specific and unrelated to backups.
  Widget _buildAppUnlockInfoCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.smartphone_outlined, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your app-unlock password and fingerprint only gate access to this app on this specific device. '
                'They are stored securely in Android Keystore / iOS Keychain and are automatically wiped if you uninstall the app. '
                'They have NO relationship to your backup encryption — changing or resetting your app-unlock credentials '
                'does not affect your ability to restore old backups.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Info card explaining that the backup password is a separate user-remembered secret, never stored.
  Widget _buildBackupPasswordInfoCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_outlined, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your backup password is a completely separate secret known only to you. '
                'The app NEVER stores it — not hashed, not encrypted, not anywhere. '
                'It is only used transiently in memory during backup/restore, then discarded. '
                'You must remember it yourself. If you forget it, encrypted backups cannot be recovered.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordSection(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Icon(
                  Icons.key,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Change Master Password',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showChangePasswordDialog(context, theme),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context, ThemeData theme) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? error;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    hintText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() => error = null),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() => error = null),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Confirm new password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() => error = null),
                  onSubmitted: (_) => _submitChangePassword(
                    ctx, setDialogState,
                    oldPasswordController, newPasswordController, confirmController,
                    (e) => setDialogState(() => error = e),
                    (v) => setDialogState(() => isLoading = v),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading ? null : () => _submitChangePassword(
                ctx, setDialogState,
                oldPasswordController, newPasswordController, confirmController,
                (e) => setDialogState(() => error = e),
                (v) => setDialogState(() => isLoading = v),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmController.dispose();
  }

  Future<void> _submitChangePassword(
    BuildContext ctx,
    StateSetter setDialogState,
    TextEditingController oldCtrl,
    TextEditingController newCtrl,
    TextEditingController confirmCtrl,
    void Function(String?) setError,
    void Function(bool) setLoading,
  ) async {
    final oldPassword = oldCtrl.text.trim();
    final newPassword = newCtrl.text.trim();
    final confirm = confirmCtrl.text.trim();

    if (oldPassword.isEmpty) {
      setError('Please enter your current password');
      return;
    }

    if (newPassword.length < 4) {
      setError('New password must be at least 4 characters');
      return;
    }

    if (newPassword != confirm) {
      setError('New passwords do not match');
      return;
    }

    if (oldPassword == newPassword) {
      setError('New password must differ from current password');
      return;
    }

    setLoading(true);
    setError(null);

    final notifier = ref.read(authStateProvider.notifier);
    final success = await notifier.changePassword(oldPassword, newPassword);

    setLoading(false);

    if (!success) {
      setError('Current password is incorrect');
    } else {
      if (ctx.mounted) Navigator.of(ctx).pop();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    }
  }

  Widget _buildAboutSection(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.lock, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${AppConstants.appVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure offline encrypted notebook',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _durationOptions = <(int, String)>[
    (0, 'Default'),
    (30, '30 seconds'),
    (60, '1 minute'),
    (120, '2 minutes'),
    (300, '5 minutes'),
    (600, '10 minutes'),
    (900, '15 minutes'),
    (1800, '30 minutes'),
  ];

  String _durationLabel(int seconds) {
    if (seconds <= 0) return 'Default';
    for (final option in _durationOptions) {
      if (option.$1 == seconds) return option.$2;
    }
    return '${seconds}s';
  }

  Widget _buildKeepUnlockedSection(
    BuildContext context,
    ThemeData theme,
    int duration,
    bool active,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Keep Unlocked For',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            subtitle: Text(
              _durationLabel(duration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                if (active) const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () => _showKeepUnlockedPicker(context, theme, duration),
          ),
        ],
      ),
    );
  }

  Future<void> _showKeepUnlockedPicker(
    BuildContext context,
    ThemeData theme,
    int currentDuration,
  ) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Keep Unlocked For',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: _durationOptions.map(
                    (option) => ListTile(
                      leading: Icon(
                        currentDuration == option.$1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: currentDuration == option.$1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      title: Text(
                        option.$2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: currentDuration == option.$1
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(option.$1),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    final notifier = ref.read(authStateProvider.notifier);
    await notifier.enableKeepUnlocked(result);
  }

  Widget _buildLockNowSection(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lock Now',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () {
              ref.read(manualLockTriggeredProvider.notifier).state = true;
              ref.read(authStateProvider.notifier).lock();
              context.go('/lock');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSection(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Icon(
                  Icons.backup_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Backup & Email to myself',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            subtitle: Text(
              'Encrypts your notes with your backup password',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showBackupPasswordDialog(context, theme),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Icon(
                  Icons.settings_backup_restore_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Restore from backup file',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            subtitle: Text(
              'Requires the backup password used at backup time',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showRestorePasswordDialog(context, theme),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How backups work:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionItem(
                  theme,
                  '1. Tap "Backup & Email to myself", enter your backup password → the encrypted .enc file is created and shared via your email app.',
                ),
                _buildInstructionItem(
                  theme,
                  '2. To restore (e.g. on a new or reinstalled device): save the .enc attachment from your email to device storage.',
                ),
                _buildInstructionItem(
                  theme,
                  '3. Tap "Restore from backup file", select the .enc file, enter the ORIGINAL backup password used when the backup was created.',
                ),
                _buildInstructionItem(
                  theme,
                  '4. Your app-unlock password on the new device does not matter — only the backup password can decrypt the file.',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Keep your backup password safe — anyone with the email attachment AND your backup password can decrypt your data. '
                          'Never forward the backup email to others. Secure your email account with 2FA.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
    );
  }

  Future<void> _showBackupPasswordDialog(BuildContext context, ThemeData theme) async {
    final container = ProviderScope.containerOf(context);
    final backupService = container.read(backupServiceProvider);

    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Backup & Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your backup password to encrypt the backup file.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'This is your separate backup password — not your app-unlock password. '
                'It is never stored anywhere. You must remember it yourself.',
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Backup password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
                onChanged: (_) => setDialogState(() => error = null),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.isEmpty) {
                        setDialogState(() => error = 'Password cannot be empty');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        error = null;
                      });

                      try {
                        await backupService.exportBackup(password);
                        
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup shared successfully')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          error = 'Failed to generate backup: $e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Backup'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
  }

  Future<void> _showRestorePasswordDialog(BuildContext context, ThemeData theme) async {
    final container = ProviderScope.containerOf(context);
    final backupService = container.read(backupServiceProvider);
    final dbFuture = container.read(databaseProvider.future);

    // 1. Let the user select the backup file first
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true, // Load the bytes directly to support cloud/scoped storage providers where path is null
    );

    if (result == null || result.files.isEmpty) {
      return; // User cancelled picking file
    }

    final pickedFile = result.files.single;
    String fileContent;
    try {
      if (pickedFile.bytes != null) {
        fileContent = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        fileContent = await File(pickedFile.path!).readAsString();
      } else {
        throw const FormatException('File data could not be retrieved from this location.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read the selected file: $e')),
        );
      }
      return;
    }

    // 2. Show the password dialog for the selected file
    if (!context.mounted) return;
    
    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    bool isLoading = false;
    
    // Dialog state variables
    bool isPasswordVerified = false;
    List<Note> decryptedNotes = [];

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal during DB operations
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!isPasswordVerified) {
            // STEP 1: Enter password to decrypt
            return AlertDialog(
              title: const Text('Enter Backup Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File: ${pickedFile.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the backup password that was used when this backup was created.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: 'Backup password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() => error = null),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final password = passwordController.text;
                          if (password.isEmpty) {
                            setDialogState(() => error = 'Password cannot be empty');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            error = null;
                          });

                          try {
                            // Decrypt data with the password
                            final notes = await backupService.decryptData(fileContent, password);
                            
                            setDialogState(() {
                              isLoading = false;
                              decryptedNotes = notes;
                              isPasswordVerified = true; // Advance to next step
                            });
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              error = e is FormatException ? e.message : 'Error: $e';
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Decrypt & Verify'),
                ),
              ],
            );
          } else {
            // STEP 2: Confirm restore/overwrite
            return AlertDialog(
              title: const Text('Confirm Restore'),
              content: Text(
                'This will overwrite existing data on this device with ${decryptedNotes.length} notes from the backup file. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setDialogState(() {
                            isLoading = true;
                          });

                          try {
                            final db = await dbFuture;
                            await db.restoreBackup(decryptedNotes);
                            container.invalidate(notesProvider);

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop(); // Close dialog
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Successfully restored ${decryptedNotes.length} notes')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              error = 'Failed to write to database: $e';
                              isPasswordVerified = false; // Go back to password screen to show error
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Continue'),
                ),
              ],
            );
          }
        },
      ),
    );

    passwordController.dispose();
  }
}
