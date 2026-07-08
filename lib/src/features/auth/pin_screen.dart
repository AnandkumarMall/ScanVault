import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../home/home_screen.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, this.isSettingPin = false});
  final bool isSettingPin;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  String? _firstPin;
  String _error = '';

  void _onDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _error = '';
      });
      if (_pin.length == 4) {
        _submit();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = '';
      });
    }
  }

  void _submit() async {
    final prefs = ref.read(vaultPrefsProvider);
    if (widget.isSettingPin) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
        });
      } else {
        if (_firstPin == _pin) {
          await prefs.setPin(_pin);
          if (mounted) Navigator.of(context).pop();
        } else {
          setState(() {
            _error = 'PINs do not match';
            _firstPin = null;
            _pin = '';
          });
        }
      }
    } else {
      final savedPin = prefs.getPin();
      if (savedPin == _pin) {
        // PIN correct, go to Home Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          _error = 'Incorrect PIN';
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String prompt = widget.isSettingPin 
        ? (_firstPin == null ? 'Enter New PIN' : 'Confirm New PIN')
        : 'Enter PIN to Unlock';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: widget.isSettingPin ? AppBar(title: const Text('Set PIN')) : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!widget.isSettingPin) ...[
              Icon(Icons.lock_outline_rounded, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
            ],
            Text(prompt, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (_error.isNotEmpty)
              Text(_error, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                );
              }),
            ),
            const SizedBox(height: 64),
            _buildNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var j = 1; j <= 3; j++)
                _buildKey((i * 3 + j).toString()),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _buildKey('0'),
            _buildKey('del', icon: Icons.backspace_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, {IconData? icon}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () {
          if (label == 'del') {
            _onDelete();
          } else {
            _onDigit(label);
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          alignment: Alignment.center,
          child: icon != null 
              ? Icon(icon, size: 28)
              : Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
