import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/patient_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/parent_model.dart';

/// DoctorPatientsScreen (Doctor View) — Patient Management
class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientProvider>().fetchPatients();
    });
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final patientProvider = context.watch<PatientProvider>();
    final patients = patientProvider.patients;
    final isLoading = patientProvider.isLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.myPatients,
          style: AppTextStyles.h1.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.textTheme.headlineMedium?.color,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
      ),
      // ── FAB: Add Patient ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        heroTag: 'addPatientFab',
        backgroundColor: AppColors.primary,
        onPressed: () => _showSearchPatientDialog(context),
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: () async {
          await patientProvider.fetchPatients();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── 1. Dashboard Summary Row ───────────────────
            _buildDashboardCard(
              context,
              title: l10n.totalPatients,
              count: '${patients.length}',
              trendValue: patientProvider.patientsTrend,
              icon: Icons.people_alt_rounded,
              color: AppColors.primary,
              onTap: () {},
            ),
            const SizedBox(height: 24),

            if (patientProvider.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'خطأ: ${patientProvider.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () {
                        patientProvider.fetchPatients();
                      },
                    ),
                  ],
                ),
              ),

            if (isLoading && patients.isEmpty)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else ...[


              // ── 3. Patient List Title ────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.patientsList,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.headlineSmall?.color,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${patients.length} ${l10n.patientSuffix}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 4. Patient List ──────────────────────────────
              if (patients.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'لا يوجد مرضى متصلين حالياً',
                      style: AppTextStyles.body
                          .copyWith(color: theme.disabledColor),
                    ),
                  ),
                )
              else
                ...patients.map((p) => _buildPatientCard(context, p)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Dashboard Card ──────────────────────────────────────────
  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String count,
    required double trendValue,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.light
                  ? color.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: AppTextStyles.h1.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (trendValue != 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (trendValue >= 0 ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        trendValue >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color:
                            trendValue >= 0 ? Colors.green : Colors.red,
                        size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${trendValue >= 0 ? "+" : ""}${trendValue.toStringAsFixed(0)}%',
                      style: AppTextStyles.caption.copyWith(
                          color:
                              trendValue >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSearchPatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PatientSearchDialog(),
    );
  }



  // ── Patient Card ────────────────────────────────────────────
  Widget _buildPatientCard(BuildContext context, UserModel patient) {
    final theme = Theme.of(context);

    String displayTitle;
    String displaySubtitle;
    String? avatarUrl;

    if (patient is ParentModel) {
      displayTitle = patient.childName.isNotEmpty ? patient.childName : patient.name;
      displaySubtitle = 'ولي الأمر: ${patient.name}';
      avatarUrl = patient.childPhotoUrl ?? patient.avatarUrl;
    } else {
      displayTitle = patient.name;
      displaySubtitle = patient.email;
      avatarUrl = patient.avatarUrl;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AvatarWidget(
          size: 48,
          imageUrl: avatarUrl,
          fallbackIcon: Icons.child_care_rounded,
        ),
        title: Text(
          displayTitle,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                patient is ParentModel ? Icons.person_outline : Icons.email_outlined,
                size: 14, color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displaySubtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              RouteNames.chatRoom,
              arguments: {
                'chatRoomId': patient.id,
                'otherUserName': patient.name,
                'otherUserAvatar': patient.avatarUrl,
              },
            );
          },
          icon: const Icon(Icons.chat_bubble_outline_rounded,
              color: AppColors.primary),
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            RouteNames.doctorPatientDetail,
            arguments: {
              'parentId': patient.id.toString(),
              'parentName': patient.name,
              'childName': patient is ParentModel ? patient.childName : patient.name,
            },
          );
        },
      ),
    );
  }


}

class _PatientSearchDialog extends StatefulWidget {
  const _PatientSearchDialog();

  @override
  State<_PatientSearchDialog> createState() => _PatientSearchDialogState();
}

class _PatientSearchDialogState extends State<_PatientSearchDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isLoading = false;
  String? _error;
  List<UserModel> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    // Start with focus to immediately allow typing
    _focusNode.requestFocus();
  }

  void _onSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results =
          await context.read<PatientProvider>().searchPatients(trimmedQuery);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.searchPatient,
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: l10n.searchByEmailOrName,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            if (_debounce?.isActive ?? false) {
                              _debounce!.cancel();
                            }
                            _controller.clear();
                            if (mounted) {
                              setState(() {
                                _results = [];
                                _isLoading = false;
                                _error = null;
                              });
                            }
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
                onChanged: (val) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(
                      const Duration(milliseconds: 500), () => _onSearch(val));
                  // Trigger rebuild to update suffix icon visibility
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text('خطأ: $_error',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator())),
              Expanded(
                child: _results.isEmpty &&
                        !_isLoading &&
                        _controller.text.length >= 2
                    ? const Center(child: Text('لا توجد نتائج مطابقة لمقترحك'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          String title = user.name;
                          String subtitle = user.email;
                          String? image = user.avatarUrl;

                          if (user is ParentModel) {
                            title = 'الطفل: ${user.childName}';
                            subtitle = 'ولي الأمر: ${user.name}\n${user.email}';
                            image = user.childPhotoUrl ?? user.avatarUrl;
                          } else {
                            title = user.name;
                            subtitle = user.email;
                          }

                          final isConnected = context.read<PatientProvider>().patients.any((p) => p.id == user.id);

                          return _SearchResultTile(
                            title: title,
                            subtitle: subtitle,
                            imageUrl: image,
                            isConnected: isConnected,
                            onSend: () async {
                              try {
                                await context
                                    .read<PatientProvider>()
                                    .sendPatientRequest(user.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.requestSent),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('خطأ: $e'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool isConnected;
  final VoidCallback onSend;

  const _SearchResultTile({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.isConnected = false,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AvatarWidget(imageUrl: imageUrl, name: title, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isConnected ? null : onSend,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isConnected ? theme.colorScheme.onSurface.withValues(alpha: 0.3) : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConnected ? 'مرتبط' : 'إرسال',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
