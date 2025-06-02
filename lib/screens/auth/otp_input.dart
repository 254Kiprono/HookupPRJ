import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String)? onCompleted;

  const OTPInput({
    super.key,
    required this.controller,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 40,
          height: 48,
          child: TextField(
            controller: controller,
            onChanged: (value) {
              if (value.length == 6 && onCompleted != null) {
                onCompleted!(value);
              }
            },
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF6E48AA), width: 2),
              ),
              counterText: '',
            ),
            maxLength: 6,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
          ),
        );
      }),
    );
  }
}
