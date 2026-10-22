import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

class ResponsiveSubmitButton extends StatelessWidget {
  const ResponsiveSubmitButton({super.key, required this.buttonText, this.onPressed, this.isLoading = false});

  final String buttonText;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isLoading ? null : onPressed,
    child: ButtonContent(text: buttonText, isLoading: isLoading),
  );
}

class ButtonContent extends StatelessWidget {
  const ButtonContent({super.key, required this.text, required this.isLoading});

  final String text;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final buttonForegroundColor = Theme.of(context).colorScheme.onPrimary;
    return Row(
      spacing: AppSpacing.sm,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(buttonForegroundColor),
            ),
          ),
        ],
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
  }
}
