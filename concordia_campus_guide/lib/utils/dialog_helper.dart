import "package:flutter/material.dart";

Future<void> showErrorPopup(
  final BuildContext context,
  final String message, {
  final String title = "Error",
}) {
  return showDialog<void>(
    context: context,
    builder: (final dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Dismiss"),
          ),
        ],
      );
    },
  );
}
