import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_audit/application/audit_log_bloc.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_vocabulary.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/widgets/audit_labels.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/utils/sheet_insets.dart';

/// Opens the filter sheet of the audit list whose [AuditLogBloc] is above [context].
Future<void> showAuditFilterSheet(BuildContext context) {
  final bloc = context.read<AuditLogBloc>();
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell's navigation bar, which would cover the bottom of the sheet.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(value: bloc, child: const AuditFilterSheet()),
  );
}

/// The filters of the audit list that Platform takes, except the user and the connection, which the event page sets.
///
/// Every choice applies at once, so the list behind the sheet follows it; the statement text is sent once the typing
/// pauses. From and to are local days sent in UTC: from as the start of its day, to as the last millisecond of its
/// day, since Platform's `to` is inclusive.
class AuditFilterSheet extends StatefulWidget {
  const AuditFilterSheet({super.key});

  @override
  State<AuditFilterSheet> createState() => _AuditFilterSheetState();
}

class _AuditFilterSheetState extends State<AuditFilterSheet> {
  late final TextEditingController _search = TextEditingController(
    text: context.read<AuditLogBloc>().state.filter.search ?? '',
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply(AuditFilter Function(AuditFilter current) update) {
    final bloc = context.read<AuditLogBloc>();
    bloc.add(AuditLogFilterChanged(update(bloc.state.filter)));
  }

  Future<void> _pickFrom(AuditFilter filter) async {
    final today = _day(clock.now());
    final to = filter.to;
    final last = to == null ? today : _day(to.toLocal());
    final from = filter.from;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: last,
      initialDate: from == null ? last : _day(from.toLocal()),
    );
    if (picked == null || !mounted) return;
    _apply((current) => current.copyWith(from: () => DateTime(picked.year, picked.month, picked.day).toUtc()));
  }

  Future<void> _pickTo(AuditFilter filter) async {
    final today = _day(clock.now());
    final from = filter.from;
    final first = from == null ? DateTime(2000) : _day(from.toLocal());
    final to = filter.to;
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: today.isBefore(first) ? first : today,
      initialDate: to == null ? (today.isBefore(first) ? first : today) : _day(to.toLocal()),
    );
    if (picked == null || !mounted) return;
    _apply(
      (current) => current.copyWith(to: () => DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999).toUtc()),
    );
  }

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocSelector<AuditLogBloc, AuditLogState, AuditFilter>(
      selector: (state) => state.filter,
      builder: (context, filter) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + sheetBottomInset(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.platform_audit_filters, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _Choices(
              title: s.platform_audit_filter_status,
              keyPrefix: 'platform-audit-status',
              values: AuditVocabulary.statuses,
              label: (value) => auditStatusLabel(s, value),
              selected: filter.status,
              onSelected: (value) => _apply((current) => current.copyWith(status: () => value)),
            ),
            _Choices(
              title: s.platform_audit_filter_statement_type,
              keyPrefix: 'platform-audit-type',
              values: AuditVocabulary.statementTypes,
              label: (value) => value,
              selected: filter.statementType,
              onSelected: (value) => _apply((current) => current.copyWith(statementType: () => value)),
            ),
            _Choices(
              title: s.platform_audit_filter_source,
              keyPrefix: 'platform-audit-source',
              values: AuditVocabulary.sources,
              label: (value) => value,
              selected: filter.source,
              onSelected: (value) => _apply((current) => current.copyWith(source: () => value)),
            ),
            _DateField(
              name: 'from',
              title: s.platform_audit_filter_from,
              value: filter.from,
              onTap: () => _pickFrom(filter),
              onClear: () => _apply((current) => current.copyWith(from: () => null)),
            ),
            _DateField(
              name: 'to',
              title: s.platform_audit_filter_to,
              value: filter.to,
              onTap: () => _pickTo(filter),
              onClear: () => _apply((current) => current.copyWith(to: () => null)),
            ),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder(
              valueListenable: _search,
              builder: (context, value, _) => TextField(
                key: const ValueKey('platform-audit-search'),
                controller: _search,
                inputFormatters: const [_TrimmedCodeUnitLimit(AuditFilter.maxSearchLength)],
                decoration: InputDecoration(
                  labelText: s.platform_audit_filter_search,
                  hintText: s.platform_audit_filter_search_hint,
                  counterText: '${value.text.trim().length}/${AuditFilter.maxSearchLength}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (text) => context.read<AuditLogBloc>().add(AuditLogSearchChanged(text)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('platform-audit-filter-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(s.platform_audit_filter_done),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single choice of [values], or Any for none.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.keyPrefix,
    required this.values,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String keyPrefix;
  final List<String> values;
  final String Function(String value) label;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                key: ValueKey('$keyPrefix-any'),
                label: Text(S.of(context).platform_audit_any),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
              for (final value in values)
                ChoiceChip(
                  key: ValueKey('$keyPrefix-$value'),
                  label: Text(label(value)),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A local day of the filter, a tap to pick it and a button to clear it.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.name,
    required this.title,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String name;
  final String title;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final value = this.value;
    return ListTile(
      key: ValueKey('platform-audit-$name'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(title),
      subtitle: Text(value == null ? s.platform_audit_filter_any_day : auditDate(context, value)),
      onTap: onTap,
      trailing: value == null
          ? null
          : IconButton(
              key: ValueKey('platform-audit-$name-clear'),
              tooltip: s.platform_audit_filter_clear_date,
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
    );
  }
}

/// Refuses an edit whose trimmed text is longer than [limit] UTF-16 code units, the unit Platform counts in.
///
/// `maxLength` counts grapheme clusters, so an emoji that is two code units would pass it as one.
class _TrimmedCodeUnitLimit extends TextInputFormatter {
  const _TrimmedCodeUnitLimit(this.limit);

  final int limit;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.text.trim().length > limit ? oldValue : newValue;
}
