import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:notally/core/constants/app_constants.dart';
import '../providers/auth_providers.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _setupPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _obscureSetup = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  late final AnimationController _animController;
  late final Animation<double> _fadeSlide;
  bool _useBiometricPrimary = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeSlide = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometric();
      _checkLockout();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authStatus = ref.read(authStateProvider);
      if (authStatus == AuthStatus.locked || authStatus == AuthStatus.unlocking) {
        if (authStatus == AuthStatus.unlocking) {
          ref.read(authStateProvider.notifier).lock();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryBiometric();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    _confirmController.dispose();
    _setupPasswordController.dispose();
    _animController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final repo = ref.read(authRepositoryProvider);
    final until = await repo.getLockoutUntil();
    if (until != null && until.isAfter(DateTime.now())) {
      _startLockoutTimer(until);
    }
  }

  void _startLockoutTimer(DateTime until) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = until.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        setState(() => _lockoutSeconds = 0);
        return;
      }
      setState(() => _lockoutSeconds = remaining.inSeconds);
    });
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    if (!_useBiometricPrimary) return;
    if (ref.read(authStateProvider) == AuthStatus.unlocked) return;
    if (ref.read(manualLockTriggeredProvider)) {
      ref.read(manualLockTriggeredProvider.notifier).state = false;
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    final hasPassword = await repo.hasMasterPassword();
    if (!hasPassword || !mounted) return;
    if (!mounted) return;
    final available = await repo.isBiometricAvailable();
    if (!available || !mounted) return;
    final success = await ref.read(authStateProvider.notifier).unlockWithBiometrics();
    if (!success && mounted) {
      setState(() {
        _useBiometricPrimary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    if (authStatus == AuthStatus.initializing || authStatus == AuthStatus.unlocking) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (authStatus == AuthStatus.unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: authStatus == AuthStatus.setup
              ? _buildSetupBody(theme)
              : _buildLockBody(theme),
        ),
      ),
    );
  }

  Widget _buildBiometricLoginUI(ThemeData theme) {
    return Column(
      children: [
        _buildAnimatedEntry(
          child: Semantics(
            label: 'Biometric Authentication',
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _unlockWithBiometrics,
                icon: const Icon(Icons.fingerprint, size: 24),
                label: const Text('Unlock with Fingerprint'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Touch fingerprint sensor or use device credentials',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _toggleBiometricAuthMode(context),
            child: Text(
              'Use password instead',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordLoginUI(ThemeData theme) {
    if (_useBiometricPrimary) {
      return Column(
        children: [
          _buildAnimatedEntry(
            child: Text(
              'Enter your master password',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildAnimatedEntry(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    enabled: _lockoutSeconds == 0,
                    decoration: InputDecoration(
                      hintText: 'Master password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onChanged: (_) => setState(() => _errorMessage = null),
                    onSubmitted: _lockoutSeconds == 0 ? (_) => _unlock() : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (_lockoutSeconds > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Too many attempts. Try again in $_lockoutSeconds seconds',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildAnimatedEntry(
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isLoading || _lockoutSeconds > 0 ? null : _unlock,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock with Password'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _toggleBiometricAuthMode(context),
              child: Text(
                'Use biometrics instead',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildAnimatedEntry(
          child: Text(
            'Biometric authentication is disabled',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildAnimatedEntry(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofocus: true,
                  enabled: _lockoutSeconds == 0,
                  decoration: InputDecoration(
                    hintText: 'Master password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                  onSubmitted: _lockoutSeconds == 0 ? (_) => _unlock() : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_lockoutSeconds > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Too many attempts. Try again in $_lockoutSeconds seconds',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildAnimatedEntry(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _isLoading || _lockoutSeconds > 0 ? null : _unlock,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Unlock with Password'),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleBiometricAuthMode(BuildContext context) {
    setState(() {
      _useBiometricPrimary = !_useBiometricPrimary;
      _passwordController.clear();
      setState(() => _errorMessage = null);
      FocusScope.of(context).unfocus();
    });
  }

  Widget _buildLockBody(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimatedEntry(
              child: Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            _buildAnimatedEntry(
              child: Semantics(
                header: true,
                child: Text(
                  'Notally',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            FutureBuilder<bool>(
              future: _canUseBiometrics(),
              builder: (context, biometricSnapshot) {
                final biometricAvailable = biometricSnapshot.data ?? false;

                if (!biometricAvailable) {
                  return _buildPasswordLoginUI(theme);
                }

                if (_useBiometricPrimary) {
                  return _buildBiometricLoginUI(theme);
                }

                return _buildPasswordLoginUI(theme);
              },
            ),

            if (!_useBiometricPrimary) ...[
              Center(
                child: TextButton(
                  onPressed: () => _toggleBiometricAuthMode(context),
                  child: Text(
                    'Use biometrics instead',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedEntry({
    required Widget child,
  }) {
    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }

  Future<bool> _canUseBiometrics() async {
    final repo = ref.read(authRepositoryProvider);
    return repo.isBiometricAvailable();
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final notifier = ref.read(authStateProvider.notifier);
    final success = await notifier.unlockWithBiometrics();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success) {
        _errorMessage = 'Biometric authentication failed';
        _useBiometricPrimary = false;
      }
    });
  }

  Future<void> _unlock() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final notifier = ref.read(authStateProvider.notifier);
    final repo = ref.read(authRepositoryProvider);

    final until = await repo.getLockoutUntil();
    if (until != null && until.isAfter(DateTime.now())) {
      _startLockoutTimer(until);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Too many attempts. Try again later.';
      });
      return;
    }

    final success = await notifier.unlockWithPassword(password);
    if (success) {
      await repo.resetFailedAttempts();
      _lockoutTimer?.cancel();
      setState(() => _isLoading = false);
      _passwordController.clear();
    } else {
      await repo.incrementFailedAttempts();
      final duration = await repo.getLockoutDuration();
      if (duration > 0) {
        final until = DateTime.now().add(Duration(seconds: duration));
        await repo.setLockoutUntil(until);
        _startLockoutTimer(until);
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect password';
      });
    }
  }

  Future<void> _createPassword() async {
    final password = _setupPasswordController.text.trim();
    final confirm = _confirmController.text.trim();
    if (password.length < AppConstants.minPasswordLength) {
      setState(() => _errorMessage =
        'Password must be at least ${AppConstants.minPasswordLength} characters');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final notifier = ref.read(authStateProvider.notifier);
    final success = await notifier.createPassword(password);
    setState(() => _isLoading = false);
    if (!success) {
      setState(() => _errorMessage = 'Failed to create password');
    } else {
      _setupPasswordController.clear();
      _confirmController.clear();
    }
  }

  Widget _buildSetupBody(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimatedEntry(
              child: Icon(
                Icons.lock_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            _buildAnimatedEntry(
              child: Semantics(
                header: true,
                child: Text(
                  'Create Master Password',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildAnimatedEntry(
              child: Text(
                'Minimum ${AppConstants.minPasswordLength} characters',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildAnimatedEntry(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextField(
                      controller: _setupPasswordController,
                      obscureText: _obscureSetup,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Master password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSetup
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscureSetup = !_obscureSetup),
                        ),
                      ),
                      onChanged: (_) => setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'Confirm password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      onChanged: (_) => setState(() => _errorMessage = null),
                      onSubmitted: (_) => _createPassword(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildAnimatedEntry(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _createPassword,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Password'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}