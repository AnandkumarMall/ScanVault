import 'package:flutter/material.dart';

import '../../app/theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _animationComplete = false;
  
  late AnimationController _masterController;
  late Animation<double> _vaultScale;
  late Animation<Offset> _docSlide;
  late Animation<double> _docOpacity;
  late Animation<double> _keyholeScale;
  late Animation<double> _glowOpacity;
  late Animation<double> _scanLineY;

  @override
  void initState() {
    super.initState();
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _vaultScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.0, 0.2, curve: Curves.elasticOut)),
    );
    
    _docSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.2, 0.4, curve: Curves.easeOutCubic)),
    );
    _docOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.2, 0.3, curve: Curves.easeIn)),
    );
    
    _keyholeScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.4, 0.6, curve: Curves.elasticOut)),
    );

    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.6, 0.8, curve: Curves.easeInOut)),
    );

    _scanLineY = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.7, 0.95, curve: Curves.linear)),
    );

    _masterController.forward().then((_) {
      if (mounted) {
        setState(() {
          _animationComplete = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationComplete) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = ScanVaultColors(isDark);

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Center(
        child: AnimatedBuilder(
          animation: _masterController,
          builder: (context, _) {
            return SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vault Circle
                  Transform.scale(
                    scale: _vaultScale.value,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: colors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Document sliding up
                  SlideTransition(
                    position: _docSlide,
                    child: Opacity(
                      opacity: _docOpacity.value,
                      child: Stack(
                        children: [
                          Container(
                            width: 88, // 160 * 0.55
                            height: 112, // 160 * 0.7
                            decoration: BoxDecoration(
                              color: colors.bgBase,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          // Folded Corner (approximate with a polygon)
                          if (_masterController.value >= 0.35)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: CustomPaint(
                                size: const Size(20, 20),
                                painter: _FoldPainter(colors.textPrimary),
                              ),
                            ),
                          
                          // Scan Brackets
                          if (_masterController.value >= 0.65)
                            ..._buildBrackets(),
                            
                          // Scan Line Sweep
                          if (_masterController.value >= 0.7 && _masterController.value <= 0.95)
                            Positioned(
                              top: 56 + (_scanLineY.value * 56), // Center is 56, range +/- 56
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: colors.accentTeal,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.accentTeal.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Keyhole and Glow
                  Transform.scale(
                    scale: _keyholeScale.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_glowOpacity.value > 0)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accentTeal.withValues(alpha: _glowOpacity.value),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        CustomPaint(
                          size: const Size(16, 24),
                          painter: _KeyholePainter(colors.bgBase),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBrackets() {
    return const [
      Positioned(top: 4, left: 4, child: _Bracket(top: true, left: true)),
      Positioned(top: 4, right: 4, child: _Bracket(top: true, left: false)),
      Positioned(bottom: 4, left: 4, child: _Bracket(top: false, left: true)),
      Positioned(bottom: 4, right: 4, child: _Bracket(top: false, left: false)),
    ];
  }
}

class _Bracket extends StatelessWidget {
  final bool top;
  final bool left;
  const _Bracket({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: ScanVaultTheme.teal, width: 2) : BorderSide.none,
          bottom: !top ? BorderSide(color: ScanVaultTheme.teal, width: 2) : BorderSide.none,
          left: left ? BorderSide(color: ScanVaultTheme.teal, width: 2) : BorderSide.none,
          right: !left ? BorderSide(color: ScanVaultTheme.teal, width: 2) : BorderSide.none,
        ),
      ),
    );
  }
}

class _FoldPainter extends CustomPainter {
  final Color color;
  _FoldPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KeyholePainter extends CustomPainter {
  final Color color;
  _KeyholePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Circle part
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.3), size.width / 2, paint);
    
    // Triangle/Rect part for the bottom of keyhole
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.4)
      ..lineTo(size.width * 0.8, size.height * 0.4)
      ..lineTo(size.width * 0.9, size.height)
      ..lineTo(size.width * 0.1, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
