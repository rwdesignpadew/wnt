import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/wnt_colors.dart';

class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    required this.value,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = '${widget.value}';
    if (_controller.text != value) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setValue(int value) {
    final safeValue = value < 0 ? 0 : value;
    widget.onChanged(safeValue);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: WntColors.inputLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(
            tooltip: 'Zmniejsz ilość',
            icon: Icons.remove,
            onPressed: widget.value > 0
                ? () => _setValue(widget.value - 1)
                : null,
          ),
          SizedBox(
            width: widget.compact ? 42 : 56,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
              onTap: () {
                _controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controller.text.length,
                );
              },
              onChanged: (text) {
                if (text.isEmpty) return;
                _setValue(int.tryParse(text) ?? 0);
              },
              onSubmitted: (text) {
                if (text.isEmpty) _setValue(0);
              },
              onTapOutside: (_) {
                if (_controller.text.isEmpty) {
                  _setValue(0);
                }
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          _button(
            tooltip: 'Zwiększ ilość',
            icon: Icons.add,
            color: WntColors.brand,
            onPressed: () => _setValue(widget.value + 1),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(
        width: widget.compact ? 34 : 40,
        height: 40,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
    );
  }
}
