import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/screens/ar_view/widgets/bottom/add_button.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../../bloc/ar_bloc/ar_state.dart';
import 'model_loader.dart';
import 'mode_selector_menu.dart';
import 'cancel_button.dart';
import 'text_input/text_input_section.dart';

/// Floating prompt input widget for AR view
class BottomWidget extends StatefulWidget {
  const BottomWidget({super.key});

  @override
  State<BottomWidget> createState() => _BottomWidgetState();
}

class _BottomWidgetState extends State<BottomWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  BottomWidgetState bottomState = BottomWidgetState.create;
  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showCreateButton() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _textController.clear();
    setState(() {
      bottomState = BottomWidgetState.create;
    });
  }

  void _showOptions() {
    setState(() {
      bottomState = BottomWidgetState.selectOption;
    });
  }

  void _onCreateFromPrompt() {
    setState(() {
      bottomState = BottomWidgetState.textInput;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onLoadRecentModels() {
    final cubit = context.read<ARCubit>();
    cubit.fetchDownloadedModels();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ARCubit, ARState>(
          builder: (context, state) {
            if (state.downloadedModels == null || state.assetModels == null) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return LoadModelDialog(
              assetModels: state.assetModels ?? [],
              downloadedModels: state.downloadedModels ?? [],
              bloc: cubit,
              onModelApply: (model) {
                cubit.loadExistingModel(model);
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ARCubit, ARState>(
      builder: (context, state) {
        // Show text input panel if user selected "Create 3D from Text Prompt"
        if (bottomState.istextInput) {
          return Stack(
            children: [
              // Bottom widget container
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    child: TextInputSection(
                      textController: _textController,
                      focusNode: _focusNode,
                    ),
                  ),
                ),
              ),
              // Cancel button outside container
              Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 220,
                  left: 16,
                  child: CancelButton(onTap: _showCreateButton)),
            ],
          );
        }

        // Show + button when idle
        if (bottomState.isCreate) {
          return AddButton(onTap: _showOptions);
        }

        if (bottomState.isselectOption) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CancelButton(
                  onTap: _showCreateButton,
                ),
                const SizedBox(height: 12),
                ModeSelectorMenu(
                  onCreateFromPrompt: _onCreateFromPrompt,
                  onLoadRecentModels: _onLoadRecentModels,
                  onDismiss: _showCreateButton,
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

enum BottomWidgetState {
  create,
  textInput,
  selectOption,
  hidden;

  bool get isCreate => this == create;
  bool get istextInput => this == textInput;
  bool get isselectOption => this == selectOption;
  bool get ishidden => this == hidden;
}
