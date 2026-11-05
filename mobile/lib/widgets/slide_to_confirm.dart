import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SlideToConfirm extends StatefulWidget {
  final String text;
  final VoidCallback onConfirmed;

  const SlideToConfirm({
    super.key,
    required this.text,
    required this.onConfirmed,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragPosition = 0.0;
  static const double _buttonSize = 56.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _buttonSize - 8.0;

        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.borderSubtle, width: 1),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Center Label
              Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Draggable Circle
              Positioned(
                left: 4.0 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition >= maxDrag * 0.85) {
                      // Confirmed!
                      widget.onConfirmed();
                      setState(() {
                        _dragPosition = maxDrag;
                      });
                    } else {
                      // Reset
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: const BoxDecoration(
                      color: AppTheme.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: AppTheme.pureBlack,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

