import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/screens/ar_view/widgets/bottom/show_downloaded_models.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../../bloc/ar_bloc/ar_state.dart';
import 'submit_button.dart';
import 'text_input.dart';
import 'mode_picker.dart';

/// Floating prompt input widget for AR view
class BottomWidget extends StatefulWidget {
  const BottomWidget({super.key});

  @override
  State<BottomWidget> createState() => _BottomWidgetState();
}

class _BottomWidgetState extends State<BottomWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Start collapsed (heightFactor = 0)
    _heightAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Auto-expand after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isExpanded = true;
          _heightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          );
          _animationController.forward(from: 0);
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    // dismiss keyboard if open
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    setState(() {
      _isExpanded = !_isExpanded;
      _heightAnimation = Tween<double>(
        begin: _isExpanded ? 0.0 : 1.0,
        end: _isExpanded ? 1.0 : 0.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );
      _animationController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ARCubit, ARState>(
      builder: (context, state) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _heightAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Toggle button at top center (always visible)
                      Center(
                        child: GestureDetector(
                          onTap: _toggleExpanded,
                          child: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 22,
                          ),
                        ),
                      ),

                      // Content (animated hide/show)
                      _mainContent(),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _mainContent() {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: _heightAnimation.value,
      child: Opacity(
        opacity: _heightAnimation.value,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 7.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode picker
              const ModePicker(),

              // Text input and buttons row
              Row(
                children: [
                  // Load models button
                  const ShowDownloadedModels(),
                  const SizedBox(width: 12),

                  // Text input field
                  Expanded(
                    child: TextInput(
                      textController: _textController,
                      focusNode: _focusNode,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Submit button
                  SubmitButton(
                    textController: _textController,
                    focusNode: _focusNode,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
