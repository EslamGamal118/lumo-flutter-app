import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

/// Auth Wrapper
///
/// Listens to auth state and navigates accordingly
/// - Authenticated → Main Layout
/// - Unauthenticated → Role Selection
/// - Loading → Loading indicator
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while checking auth state
        if (authProvider.isLoading) {
          return Scaffold(
            body: LoadingIndicator(message: (isAr ? 'جاري التحقق...' : 'Verifying...')),
          );
        }

        // Navigate based on auth state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (authProvider.isAuthenticated) {
            // User is logged in
            Navigator.pushReplacementNamed(context, RouteNames.mainLayout);
          } else {
            // User is not logged in
            Navigator.pushReplacementNamed(context, RouteNames.roleSelection);
          }
        });

        // Show loading while navigating
        return Scaffold(
          body: LoadingIndicator(),
        );
      },
    );
  }
}