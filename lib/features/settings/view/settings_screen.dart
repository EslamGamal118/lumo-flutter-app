import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/auth_provider.dart';

import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/locale_provider.dart';
import '../../../shared/providers/patient_provider.dart';
import '../../../shared/providers/community_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../chat/view_model/chat_view_model.dart';
import '../../profile/view_model/profile_view_model.dart';
import '../../../core/di/dependency_injection.dart';

/// SettingsScreen (Screen 13)
///
/// Sections:
///   - Account: Edit Profile, Change Password
///   - General: Notifications (Toggle), Language, Dark Mode (Toggle)
///   - Support: Privacy Policy, About Us, Log Out (Red)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: theme.iconTheme.color),
        ),
        title: Text(
          l10n.settings,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── Account Section ─────────────────────────────────
          _buildSectionHeader(
              l10n.accountSection, Icons.person_outline_rounded),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.edit_outlined,
              iconColor: AppColors.primary,
              title: l10n.editProfile,
              onTap: () => Navigator.pushNamed(context, RouteNames.editProfile),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: l10n.changePassword,
              onTap: () =>
                  Navigator.pushNamed(context, RouteNames.changePassword),
            ),
          ]),
          const SizedBox(height: 20),

          // ── General Section ─────────────────────────────────
          _buildSectionHeader(l10n.generalSection, Icons.tune_rounded),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.language_rounded,
              iconColor: const Color(0xFF22C55E),
              title: l10n.language,
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Consumer<LocaleProvider>(
                  builder: (context, localeProvider, _) {
                    return Text(
                      localeProvider.isArabic ? l10n.arabic : l10n.english,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              onTap: () {
                context.read<LocaleProvider>().toggleLocale();
              },
            ),
            _buildDivider(),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor: const Color(0xFF6366F1),
                  title: l10n.darkMode,
                  subtitle:
                      themeProvider.isDarkMode ? l10n.enabled : l10n.disabled,
                  value: themeProvider.isDarkMode,
                  onChanged: (v) {
                    themeProvider.toggleTheme();
                  },
                );
              },
            ),
          ]),
          const SizedBox(height: 20),

          // ── Support Section ─────────────────────────────────
          _buildSectionHeader(l10n.supportSection, Icons.help_outline_rounded),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF06B6D4),
              title: l10n.privacy,
              onTap: () => _showPrivacyPolicyDialog(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: l10n.licenses,
              onTap: () => _showLicensesDialog(),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.primary,
              title: l10n.about,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/lumo-logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LUMO',
                              style: AppTextStyles.h2
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'v1.0.0',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ],
                    ),
                    content: Text(
                      l10n.aboutAppContent.replaceAll('\\n', '\n'),
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.ok,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 20),

          // ── Logout ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.15),
                ),
              ),
              child: ListTile(
                onTap: () async {
                  // 1. Clear memory state of all major providers
                  context.read<PatientProvider>().resetState();
                  context.read<CommunityProvider>().resetState();
                  context.read<UserProvider>().clearUser();

                  // 2. Clear ViewModels
                  getIt<ChatViewModel>().resetState();
                  getIt<ProfileViewModel>().resetState(); // Clears profile state

                  // 3. Clear auth and local caches
                  await context.read<AuthProvider>().logout();

                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    RouteNames.login,
                    (route) => false,
                  );
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.destructive,
                    size: 20,
                  ),
                ),
                title: Text(
                  l10n.logout,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.destructive.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // App version
          Center(
            child: Text(
              'LUMO v1.0.0',
              style: AppTextStyles.caption.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Privacy Policy Dialog ─────────────────────────────────
  void _showPrivacyPolicyDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.privacy,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.privacyPolicyContent.replaceAll('\\n', '\n'),
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.ok,
              style: AppTextStyles.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Licenses Dialog ──────────────────────────────────────
  void _showLicensesDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.description_outlined,
                color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.licenses,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'البرنامج لا يحتوي علي تراخيص حتي الان',
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.ok,
              style: AppTextStyles.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_left_rounded,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
          ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontSize: 11,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        activeThumbColor: Colors.white,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(right: 72),
      child: Divider(
          height: 1, thickness: 1, color: Theme.of(context).dividerColor),
    );
  }
}
