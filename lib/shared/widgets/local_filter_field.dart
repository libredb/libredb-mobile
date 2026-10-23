import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The text field of a filter over a list already on screen, which sends no request.
///
/// It reports the text as typed through [onChanged]; whoever filters compares it with `matchesSearch` from
/// `lib/shared/utils/search_fold.dart`, the one fold of every local search, so `istanbul` finds `İstanbul` as Studio's
/// tree filter does. A clear button shows while it holds text.
class LocalFilterField extends StatefulWidget {
  const LocalFilterField({super.key, required this.onChanged, this.hintText});

  final ValueChanged<String> onChanged;

  /// What the empty field says, `Filter` when null.
  final String? hintText;

  @override
  State<LocalFilterField> createState() => _LocalFilterFieldState();
}

class _LocalFilterFieldState extends State<LocalFilterField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText ?? s.local_filter_hint,
            prefixIcon: const Icon(Icons.filter_list),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), tooltip: s.local_filter_clear, onPressed: _clear),
          ),
        ),
      ),
    );
  }
}
