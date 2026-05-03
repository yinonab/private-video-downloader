import "package:flutter/material.dart";

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.autocorrect = false,
    this.validator,
    this.maxLines,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final String? Function(String?)? validator;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      textAlignVertical: TextAlignVertical.center,
      maxLines: maxLines ?? 1,
      validator: validator,
      decoration: InputDecoration(labelText: label),
      textAlign: TextAlign.right,
    );
  }
}
