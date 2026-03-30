import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";

class CalendarPicker extends StatefulWidget {
  const CalendarPicker({super.key});

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker> {
  bool _showError = false;

  @override
  Widget build(final BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Select a Calendar",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: context.watch<HomeViewModel>().selectedCalendarId,
                hint: const Text("Choose a calendar"),
                items: context.watch<HomeViewModel>().getCalendarTitles.map((final calendarOption) {
                  return DropdownMenuItem<String>(
                    value: calendarOption.id,
                    child: Text(calendarOption.title),
                  );
                }).toList(),
                onChanged: (final newValue) {
                  setState(() {
                    context.read<HomeViewModel>().selectedCalendarId = newValue;
                  });
                },
              ),
            ),
            const SizedBox(height: 16.0),
            if (_showError)
              const Text("Selection cannot be empty", style: TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: () {
                if (context.read<HomeViewModel>().selectedCalendarId != null) {
                  context.read<HomeViewModel>().toggleNextClassFabVisibility(true);
                  // To clear cache and force calendar refresh
                  context.read<HomeViewModel>().clearUpcomingClass();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Google Calendar imported successfully!")),
                  );
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _showError = true;
                  });
                }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(AppTheme.concordiaMaroon),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              child: const Text("Confirm", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
