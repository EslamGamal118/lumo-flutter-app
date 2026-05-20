import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../session/view_model/session_view_model.dart';
import '../../session/models/session_part.dart';
import 'package:provider/provider.dart';

class SessionConfigBottomSheet extends StatefulWidget {
  final int receiverId;
  final void Function(List<SessionPart> parts)? onSubmit;

  const SessionConfigBottomSheet({
    super.key,
    required this.receiverId,
    this.onSubmit,
  });

  static void show(
    BuildContext context, {
    required int receiverId,
    void Function(List<SessionPart> parts)? onSubmit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionConfigBottomSheet(
        receiverId: receiverId,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<SessionConfigBottomSheet> createState() =>
      _SessionConfigBottomSheetState();
}

class _SessionConfigBottomSheetState extends State<SessionConfigBottomSheet> {
  final List<SessionPart> _tempParts = [];
  DateTime? _scheduledDate;

  void _addPart() async {
    final result = await showDialog<SessionPart>(
      context: context,
      builder: (context) => const _AddPartDialog(),
    );

    if (result != null) {
      setState(() {
        _tempParts.add(result);
      });
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('ar'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledDate ?? DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _handleSubmit() async {
    if (_tempParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إضافة جزء واحد على الأقل')),
      );
      return;
    }

    final viewModel = context.read<SessionViewModel>();
    await viewModel.createSession(
      patientId: widget.receiverId,
      parts: _tempParts,
      scheduledDate: _scheduledDate,
    );

    if (mounted) {
      if (viewModel.errorMessage == null) {
        widget.onSubmit?.call(_tempParts);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.errorMessage!),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  String get _formattedSchedule {
    if (_scheduledDate == null) return 'اختر التاريخ والوقت';
    final d = _scheduledDate!;
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour >= 12 ? 'م' : 'ص';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year} - $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              const Icon(Icons.playlist_add_rounded,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text('بناء تسلسل الجلسة', style: AppTextStyles.h3),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Date/Time Picker
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formattedSchedule,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: _scheduledDate != null ? FontWeight.w600 : FontWeight.normal,
                        color: _scheduledDate != null
                            ? theme.textTheme.bodyLarge?.color
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  if (_scheduledDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _scheduledDate = null),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: AppColors.mutedForeground),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Parts List
          Flexible(
            child: _tempParts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _tempParts.length,
                    itemBuilder: (context, index) {
                      final part = _tempParts[index];
                      return _buildPartItem(part, index);
                    },
                  ),
          ),

          const SizedBox(height: 24),

          // Add Part Button
          OutlinedButton.icon(
            onPressed: _addPart,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة جزء جديد للجلسة',
                style: TextStyle(fontFamily: 'Cairo')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),

          // Start Button
          AppButton(
            text: 'إضافة الجلسة',
            onPressed: _handleSubmit,
            isLoading: context.watch<SessionViewModel>().isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.layers_clear_outlined,
              size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'لا يوجد أجزاء مضافة بعد',
            style:
                AppTextStyles.body.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildPartItem(SessionPart part, int index) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.typeLabel(context),
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.bold)),
                Text('${part.durationMinutes} دقيقة',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.mutedForeground)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _tempParts.removeAt(index)),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.destructive),
          ),
        ],
      ),
    );
  }
}

class _AddPartDialog extends StatefulWidget {
  const _AddPartDialog();

  @override
  State<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<_AddPartDialog> {
  String _selectedType = 'games';
  int _selectedDuration = 10;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(isAr ? 'إضافة جزء للجلسة' : 'Add Session Part',
          textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: InputDecoration(
                labelText: isAr ? 'النوع' : 'Type', labelStyle: const TextStyle(fontFamily: 'Cairo')),
            items: [
              DropdownMenuItem(
                  value: 'study',
                  child: Text(isAr ? 'تعلم' : 'Study', style: const TextStyle(fontFamily: 'Cairo'))),
              DropdownMenuItem(
                  value: 'games',
                  child: Text(isAr ? 'ألعاب' : 'Games', style: const TextStyle(fontFamily: 'Cairo'))),
              DropdownMenuItem(
                  value: 'stories',
                  child: Text(isAr ? 'قصص' : 'Stories', style: const TextStyle(fontFamily: 'Cairo'))),
              DropdownMenuItem(
                  value: 'drawing',
                  child: Text(isAr ? 'رسم' : 'Drawing', style: const TextStyle(fontFamily: 'Cairo'))),
            ],
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
                labelText: 'المدة (بالدقائق)',
                labelStyle: TextStyle(fontFamily: 'Cairo')),
            items: [5, 10, 15, 20, 30]
                .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text('$d دقيقة',
                        style: const TextStyle(fontFamily: 'Cairo'))))
                .toList(),
            onChanged: (val) => setState(() => _selectedDuration = val!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () => Navigator.pop(
              context,
              SessionPart(
                  type: _selectedType, durationMinutes: _selectedDuration)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
