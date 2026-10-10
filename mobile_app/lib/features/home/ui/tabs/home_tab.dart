import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/constants/app_text_styles.dart';
import 'package:bell_pepper_app/features/environmental_stress/ui/environmental_stress_screen.dart';
import 'package:bell_pepper_app/features/home/models/dashboard_module.dart';
import 'package:bell_pepper_app/features/home/models/dashboard_modules_data.dart';
import 'package:bell_pepper_app/features/home/ui/widgets/module_card.dart';
import 'package:bell_pepper_app/services/auth_service.dart';
import 'package:bell_pepper_app/services/user_repository.dart';
import 'package:bell_pepper_app/ui/widgets/glow_circle.dart';

/// Dashboard tab: greets the grower by name and shows the detection/recovery
/// modules as a grid, each flagged implemented or coming soon. Tapping an
/// implemented module swaps the tab's content in place (dashboard grid <->
/// module screen) so the shared top bar and bottom nav stay visible instead
/// of being covered by a pushed route.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  DashboardModule? _openModule;

  void _handleModuleTap(BuildContext context, DashboardModule module) {
    if (module.status != ModuleStatus.implemented) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${module.title} — coming soon.')));
      return;
    }
    setState(() => _openModule = module);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -60,
          child: GlowCircle(
            size: 200,
            colors: [
              AppColors.lightGreen.withValues(alpha: 0.4),
              AppColors.primaryGreen.withValues(alpha: 0.0),
            ],
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
          child: _openModule == null
              ? _DashboardView(onModuleTap: (module) => _handleModuleTap(context, module))
              : EnvironmentalStressScreen(
                  onBack: () => setState(() => _openModule = null),
                ),
        ),
      ],
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.onModuleTap});

  final ValueChanged<DashboardModule> onModuleTap;

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final fallbackName = user?.isAnonymous == true
        ? 'Demo User'
        : (user?.email?.split('@').first ?? 'Grower');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder(
          future: (user == null || user.isAnonymous)
              ? null
              : UserRepository().getUserProfile(user.uid),
          builder: (context, snapshot) {
            final name = snapshot.data?.fullName;
            final greetingName = (name == null || name.isEmpty)
                ? fallbackName
                : name.split(' ').first;
            return RichText(
              text: TextSpan(
                style: AppTextStyles.appTitle,
                children: [
                  const TextSpan(text: 'Welcome back,\n'),
                  TextSpan(
                    text: greetingName,
                    style: const TextStyle(color: AppColors.primaryGreen),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Smart insights for healthier peppers and better greenhouse decisions.',
          style: AppTextStyles.screenSubtitle,
        ),
        const SizedBox(height: 24),
        const Text('Your Modules', style: AppTextStyles.featureCardTitle),
        const SizedBox(height: 14),
        for (var i = 0; i < dashboardModules.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ModuleCard(
                    module: dashboardModules[i],
                    onTap: () => onModuleTap(dashboardModules[i]),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < dashboardModules.length
                      ? ModuleCard(
                          module: dashboardModules[i + 1],
                          onTap: () => onModuleTap(dashboardModules[i + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
