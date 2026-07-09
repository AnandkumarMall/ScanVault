import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../home/home_screen.dart';
import '../../app/theme.dart';
import 'dart:math' as math;

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, this.isSettingPin = false});
  final bool isSettingPin;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _firstPin;
  String _error = '';
  
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerError(String msg) {
    setState(() {
      _error = msg;
      _pin = '';
      if (widget.isSettingPin && _firstPin != null) {
        _firstPin = null;
      }
    });
    _shakeController.forward(from: 0.0);
  }

  void _onDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _error = '';
      });
      if (_pin.length == 4) {
        // slight delay to show the 4th dot filling up
        Future.delayed(const Duration(milliseconds: 150), _submit);
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
          _triggerError('PINs do not match');
        }
      }
    } else {
      final savedPin = prefs.getPin();
      if (savedPin == _pin) {
        // PIN correct, go to Home Screen
        if (mounted) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        _triggerError('Incorrect PIN');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);
    
    final String prompt = widget.isSettingPin 
        ? (_firstPin == null ? 'Set new vault PIN' : 'Confirm new PIN')
        : 'Enter your vault PIN';

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: widget.isSettingPin ? AppBar(
        title: const Text('Security'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ) : null,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final sineValue = math.sin(_shakeController.value * math.pi * 4);
            return Transform.translate(
              offset: Offset(sineValue * 10, 0),
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              if (!widget.isSettingPin) ...[
                _VaultIcon(colors: colors),
                const SizedBox(height: 24),
                Text('ScanVault', style: theme.textTheme.displayMedium),
                const SizedBox(height: 8),
              ],
              Text(prompt, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 20,
                child: _error.isNotEmpty
                    ? Text(_error, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600))
                    : const SizedBox(),
              ),
              const SizedBox(height: 32),
              
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? colors.accentTeal : Colors.transparent,
                      border: Border.all(color: colors.accentTeal, width: 2),
                    ),
                  );
                }),
              ),
              
              const Spacer(),
              _buildNumpad(colors),
              const SizedBox(height: 32),
              
              if (!widget.isSettingPin)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Forgot PIN is not implemented in this demo.')),
                    );
                  },
                  child: const Text('Forgot PIN?'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad(ScanVaultColors colors) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('1', '', colors),
            const SizedBox(width: 16),
            _buildKey('2', 'ABC', colors),
            const SizedBox(width: 16),
            _buildKey('3', 'DEF', colors),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('4', 'GHI', colors),
            const SizedBox(width: 16),
            _buildKey('5', 'JKL', colors),
            const SizedBox(width: 16),
            _buildKey('6', 'MNO', colors),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('7', 'PQRS', colors),
            const SizedBox(width: 16),
            _buildKey('8', 'TUV', colors),
            const SizedBox(width: 16),
            _buildKey('9', 'WXYZ', colors),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88),
            _buildKey('0', '', colors),
            const SizedBox(width: 16),
            _buildKey('del', '', colors, icon: Icons.backspace_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, String letters, ScanVaultColors colors, {IconData? icon}) {
    final isDel = label == 'del';
    
    return Material(
      color: isDel ? Colors.transparent : colors.bgElevated,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        onTap: () {
          if (isDel) {
            _onDelete();
          } else {
            _onDigit(label);
          }
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: isDel
              ? Icon(icon, size: 28, color: colors.textPrimary)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label, 
                      style: TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w600, 
                        color: colors.textPrimary,
                        height: letters.isEmpty ? 1.5 : 1.0,
                      )
                    ),
                    if (letters.isNotEmpty)
                      Text(
                        letters, 
                        style: TextStyle(
                          fontSize: 9, 
                          color: colors.textTertiary, 
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        )
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _VaultIcon extends StatelessWidget {
  final ScanVaultColors colors;
  const _VaultIcon({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(80, 80),
            painter: _VaultPainter(color: colors.textPrimary, bgColor: colors.bgBase),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.textPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.bgBase, width: 2),
              ),
              child: Icon(
                Icons.security_rounded,
                size: 14,
                color: colors.accentGold,
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _VaultPainter extends CustomPainter {
  final Color color;
  final Color bgColor;
  _VaultPainter({required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw the circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
      
    // Draw the document cutout
    final docRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * 0.55, height: size.height * 0.7),
      const Radius.circular(8),
    );
    canvas.drawRRect(docRect, bgPaint);
    
    // Fold
    final foldPath = Path()
      ..moveTo(docRect.right, docRect.top + 16)
      ..lineTo(docRect.right - 16, docRect.top)
      ..lineTo(docRect.right, docRect.top)
      ..close();
    canvas.drawPath(foldPath, paint);

    // Keyhole
    final keyholePaint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 - 4), 6, keyholePaint);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2 + 6), width: 8, height: 12),
      keyholePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
