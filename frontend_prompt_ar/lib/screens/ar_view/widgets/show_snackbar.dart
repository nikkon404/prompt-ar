// show snackbar for AR view
import 'package:flutter/material.dart';

void showSnackbar(BuildContext context, String message) {
  final screnHeight = MediaQuery.of(context).size.height;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.hideCurrentSnackBar();
  scaffoldMessenger.showSnackBar(
    SnackBar(
        content:
            Text("🤖: $message", style: const TextStyle(color: Colors.white)),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            // theme primary color with 0.9 opacity
            Theme.of(context).colorScheme.primary.withAlpha(100),
        // make it appear from the top
        margin: EdgeInsets.only(
          bottom: screnHeight * 0.2,
        )),
  );
}
