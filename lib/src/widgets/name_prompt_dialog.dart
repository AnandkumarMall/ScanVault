import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../utils/document_name_service.dart';

class NamePromptDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final DocumentNameService nameService;

  const NamePromptDialog({
    super.key,
    required this.title,
    required this.initialName,
    required this.nameService,
  });

  @override
  State<NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<NamePromptDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.addListener(_validate);
    // Initial validation without showing error if it's identical to current
    _validate();
  }

  @override
  void dispose() {
    _controller.removeListener(_validate);
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _controller.text;
    String? error;
    
    if (!DocumentNameService.isValid(text)) {
      if (text.trim().isEmpty) {
        error = 'Name cannot be empty';
      } else if (text.length > 100) {
        error = 'Name is too long (max 100 characters)';
      }
    } else if (widget.nameService.isDuplicate(text)) {
      error = 'A document with this name already exists';
    }

    if (_errorText != error) {
      setState(() => _errorText = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);

    return AlertDialog(
      backgroundColor: colors.bgElevated,
      title: Text(widget.title, style: TextStyle(color: colors.textPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Name',
          labelStyle: TextStyle(color: colors.textSecondary),
          errorText: _errorText,
          errorStyle: TextStyle(color: ScanVaultTheme.error),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.textTertiary),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.accentTeal),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: ScanVaultTheme.error),
          ),
        ),
        onSubmitted: (v) {
          if (_errorText == null) {
            Navigator.of(context).pop(_controller.text.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _errorText == null
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accentTeal,
            foregroundColor: colors.bgBase,
            disabledBackgroundColor: colors.textTertiary.withOpacity(0.3),
            disabledForegroundColor: colors.textTertiary,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
