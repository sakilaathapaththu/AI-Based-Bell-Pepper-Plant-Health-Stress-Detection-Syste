import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/home/ui/home_screen.dart';
import 'package:bell_pepper_app/models/user_profile.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/user_repository.dart';
import 'package:bell_pepper_app/ui/widgets/app_text_field.dart';
import 'package:bell_pepper_app/ui/widgets/brand_header.dart';
import 'package:bell_pepper_app/ui/widgets/glow_circle.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _userRepository = UserRepository();

  bool _isRegistering = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    UserCredential? credential;
    try {
      credential = await _authService.registerWithEmail(
        fullName: fullName,
        email: email,
        password: _passwordController.text,
      );
      try {
        await _userRepository.createUserProfile(
          UserProfile(uid: credential.user!.uid, fullName: fullName, email: email),
        );
      } catch (_) {
        // Firestore write failed after the auth account was created — roll
        // back so we don't leave an auth user with no profile behind.
        await credential.user?.delete();
        rethrow;
      }
      _goToHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Could not create your account. Please try again.');
    } catch (_) {
      _showError('Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: GlowCircle(
              size: 240,
              colors: [
                AppColors.lightGreen.withValues(alpha: 0.45),
                AppColors.primaryGreen.withValues(alpha: 0.05),
              ],
            ),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: GlowCircle(
              size: 260,
              colors: [
                AppColors.primaryGreen.withValues(alpha: 0.12),
                AppColors.lightGreen.withValues(alpha: 0.0),
              ],
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandHeader(
                              trailing: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close, color: AppColors.subtitleGrey),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    AppStrings.createYourAccount,
                                    style: AppTextStyles.screenTitle,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    AppStrings.signUpSubtitle,
                                    style: AppTextStyles.screenSubtitle,
                                  ),
                                  const SizedBox(height: 26),
                                  AppTextField(
                                    label: AppStrings.fullNameLabel,
                                    hint: AppStrings.fullNameHint,
                                    controller: _fullNameController,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    validator: _validateFullName,
                                    prefixIcon: Icons.person_outline,
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextField(
                                    label: AppStrings.emailLabel,
                                    hint: AppStrings.emailHint,
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: _validateEmail,
                                    prefixIcon: Icons.mail_outline,
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextField(
                                    label: AppStrings.passwordLabel,
                                    hint: AppStrings.passwordHint,
                                    controller: _passwordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.next,
                                    validator: _validatePassword,
                                    prefixIcon: Icons.lock_outline,
                                  ),
                                  const SizedBox(height: 18),
                                  AppTextField(
                                    label: AppStrings.confirmPasswordLabel,
                                    hint: AppStrings.confirmPasswordHint,
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    validator: _validateConfirmPassword,
                                    prefixIcon: Icons.lock_outline,
                                  ),
                                  const SizedBox(height: 26),
                                  PrimaryButton(
                                    label: AppStrings.signUp,
                                    isLoading: _isRegistering,
                                    onPressed: _isRegistering ? null : _handleSignUp,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    AppStrings.logInPrompt,
                                    style: AppTextStyles.loginPrompt,
                                  ),
                                  GestureDetector(
                                    onTap: _isRegistering
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    child: const Text(
                                      AppStrings.loginLink,
                                      style: AppTextStyles.loginLink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return AppStrings.fullNameRequired;
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return AppStrings.emailRequired;
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return AppStrings.emailInvalid;
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return AppStrings.passwordRequired;
    if (password.length < 6) return AppStrings.passwordTooShort;
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirmPassword = value ?? '';
    if (confirmPassword.isEmpty) return AppStrings.confirmPasswordRequired;
    if (confirmPassword != _passwordController.text) {
      return AppStrings.passwordMismatch;
    }
    return null;
  }
}
