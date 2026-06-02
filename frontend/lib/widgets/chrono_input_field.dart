import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Shared input field widget with ChronoFlow's minimalist design.
/// Replaces the duplicated _buildInput methods across login, register,
/// bind-email, change-nickname, change-phone, change-password, and
/// change-group-nickname pages.
class ChronoInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool focused;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const ChronoInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.focused,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppConstants.placeholderGray,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        Container(
          height: 1,
          color: focused ? Colors.black : Colors.black12,
        ),
      ],
    );
  }
}
