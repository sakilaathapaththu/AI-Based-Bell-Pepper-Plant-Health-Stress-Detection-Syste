import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/auth/ui/login_screen.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/user_repository.dart';
import 'package:bell_pepper_app/ui/widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final fallbackName = user?.isAnonymous == true ? 'Demo User' : 'Grower';
    final email = user?.isAnonymous == true ? null : user?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.titleDark),
        title: const Text('Profile', style: AppTextStyles.screenTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.featureIconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.primaryGreen,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder(
                future: (user == null || user.isAnonymous)
                    ? null
                    : UserRepository().getUserProfile(user.uid),
                builder: (context, snapshot) {
                  final name = snapshot.data?.fullName;
                  final label = (name == null || name.isEmpty) ? fallbackName : name;
                  return Center(
                    child: Text(label, style: AppTextStyles.screenTitle),
                  );
                },
              ),
              if (email != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(email, style: AppTextStyles.screenSubtitle),
                ),
              ],
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Sign Out',
                onPressed: () => _signOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
