import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_strings.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/home/ui/home_screen.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/ui/widgets/app_text_field.dart';
import 'package:bell_pepper_app/ui/widgets/brand_header.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';
import 'package:bell_pepper_app/ui/widgets/secondary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isSigningIn = false;
  bool _isContinuingAsDemo = false;

  bool get _isBusy => _isSigningIn || _isContinuingAsDemo;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleLogIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSigningIn = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _goToHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _handleDemoUser() async {
    setState(() => _isContinuingAsDemo = true);
    try {
      await _authService.signInAsDemoUser();
      _goToHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Could not start a demo session.');
    } finally {
      if (mounted) setState(() => _isContinuingAsDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandHeader(),
                const SizedBox(height: 36),
                const Text(AppStrings.welcomeBack, style: AppTextStyles.screenTitle),
                const SizedBox(height: 8),
                const Text(
                  AppStrings.signInSubtitle,
                  style: AppTextStyles.screenSubtitle,
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: AppStrings.emailLabel,
                  hint: AppStrings.emailHint,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: AppStrings.passwordLabel,
                  hint: AppStrings.passwordHint,
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    // TODO: navigate to password reset once that flow exists.
                    onPressed: _isBusy ? null : () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      AppStrings.forgotPassword,
                      style: AppTextStyles.linkLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: AppStrings.logIn,
                  isLoading: _isSigningIn,
                  onPressed: _isBusy ? null : _handleLogIn,
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(AppStrings.or, style: AppTextStyles.dividerLabel),
                ),
                const SizedBox(height: 18),
                SecondaryButton(
                  label: AppStrings.continueAsDemoUser,
                  isLoading: _isContinuingAsDemo,
                  onPressed: _isBusy ? null : _handleDemoUser,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        AppStrings.signUpPrompt,
                        style: AppTextStyles.loginPrompt,
                      ),
                      GestureDetector(
                        // TODO: navigate to account creation once that screen exists.
                        onTap: _isBusy ? null : () {},
                        child: const Text(
                          AppStrings.createAccount,
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
}
