import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Поле ввода, которое сообщает о новом значении только через [delay]
/// после окончания ввода, а не на каждое нажатие клавиши.
class DebouncedTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final IconData? icon;
  final bool digitsOnly;
  final Duration delay;

  const DebouncedTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.digitsOnly = false,
    this.delay = const Duration(milliseconds: 400),
  });

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final _controller = TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Значение пришло из адреса (кнопка «назад», сброс фильтров):
    // показываем его, если пользователь сейчас не печатает.
    if (widget.value != _controller.text && !(_timer?.isActive ?? false)) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (text != widget.value) widget.onChanged(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      keyboardType: widget.digitsOnly ? TextInputType.number : null,
      inputFormatters: widget.digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
