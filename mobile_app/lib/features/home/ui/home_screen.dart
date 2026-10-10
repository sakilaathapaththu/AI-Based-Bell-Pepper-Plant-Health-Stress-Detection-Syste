import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/auth/ui/login_screen.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/user_repository.dart';

/// Placeholder landing screen after sign-in. Real dashboard content (the
/// RGB/thermal/environmental/recovery features) lands here incrementally.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
    final fallbackLabel = user?.isAnonymous == true
        ? 'Demo User'
        : (user?.email ?? 'grower');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.titleDark),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: user == null || user.isAnonymous
            ? Text('Signed in as $fallbackLabel', style: AppTextStyles.screenTitle)
            : FutureBuilder(
                future: UserRepository().getUserProfile(user.uid),
                builder: (context, snapshot) {
                  final name = snapshot.data?.fullName;
                  final label = (name == null || name.isEmpty) ? fallbackLabel : name;
                  return Text(
                    'Welcome, $label',
                    style: AppTextStyles.screenTitle,
                  );
                },
              ),
      ),
    );
  }
}
