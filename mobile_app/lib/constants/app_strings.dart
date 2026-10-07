/// Centralized user-facing copy. Pulling strings out of widgets makes future
/// localization and copy changes a single-file edit instead of a hunt.
class AppStrings {
  AppStrings._();

  static const String appName = 'PepperCare AI';
  static const String appTagline = 'Smart Greenhouse Monitoring';
  static const String splashCaption = 'Bell pepper greenhouse intelligence';
  static const String loading = 'Loading...';

  static const String brandWordmarkPepper = 'Pepper';
  static const String brandWordmarkCare = 'Care';
  static const String brandWordmarkSuffix = ' AI';

  static const String skip = 'Skip';
  static const String getStarted = 'Get Started';
  static const String loginPrompt = 'Already have an account?  ';
  static const String loginLink = 'Log In';

  static const String welcomeBack = 'Welcome back';
  static const String signInSubtitle = 'Sign in to continue to PepperCare AI.';
  static const String emailLabel = 'Email';
  static const String emailHint = 'grower@example.com';
  static const String passwordLabel = 'Password';
  static const String passwordHint = '••••••••';
  static const String forgotPassword = 'Forgot password?';
  static const String logIn = 'Log In';
  static const String or = 'or';
  static const String continueAsDemoUser = 'Continue as Demo User';
  static const String signUpPrompt = 'New to PepperCare AI?  ';
  static const String createAccount = 'Create account';

  static const String emailRequired = 'Enter your email';
  static const String emailInvalid = 'Enter a valid email address';
  static const String passwordRequired = 'Enter your password';
  static const String passwordTooShort = 'Password must be at least 6 characters';
}
