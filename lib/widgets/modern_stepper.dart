import 'package:flutter/material.dart';
import 'package:duitkita/config/app_theme.dart';

class ModernStepper extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final Color? activeColor;
  final Color? inactiveColor;

  const ModernStepper({
    Key? key,
    required this.steps,
    required this.currentStep,
    this.activeColor,
    this.inactiveColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final actColor = activeColor ?? AppTheme.primary;
    final inactColor = inactiveColor ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: List.generate(
          steps.length * 2 - 1,
          (index) {
            if (index.isEven) {
              final stepIndex = index ~/ 2;
              final isActive = stepIndex <= currentStep;
              final isCurrent = stepIndex == currentStep;

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      steps[stepIndex],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? actColor : inactColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive ? actColor : inactColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Connector line
              final stepIndex = index ~/ 2;
              final isActive = stepIndex < currentStep;
              return Container(
                width: 8,
                height: 3,
                margin: const EdgeInsets.only(top: 28),
                color: isActive ? actColor : inactColor.withValues(alpha: 0.3),
              );
            }
          },
        ),
      ),
    );
  }
}
