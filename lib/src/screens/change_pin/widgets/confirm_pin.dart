import 'package:flutter/material.dart';

import '../../yivi_confirm_pin_scaffold.dart';

class ConfirmPin extends StatelessWidget {
  static const String routeName = 'change_pin/confirm_pin';

  final void Function(String) confirmNewPin;
  final VoidCallback cancel;

  const ConfirmPin({required this.confirmNewPin, required this.cancel});

  @override
  Widget build(BuildContext context) {
    return YiviConfirmPinScaffold(
      submit: confirmNewPin,
      cancel: cancel,
      instructionKey: 'change_pin.confirm_pin.instruction',
      longPin: ModalRoute.of(context)!.settings.arguments as bool,
    );
  }
}
