import 'package:concordia_campus_guide/domain/models/building.dart';
import 'package:concordia_campus_guide/ui/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class OpeningHoursWidget extends StatefulWidget {
  final Building building;

  const OpeningHoursWidget({super.key, required this.building});

  @override
  State<OpeningHoursWidget> createState() => _OpeningHoursWidgetState();
}

class _OpeningHoursWidgetState extends State<OpeningHoursWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.building.isOpen();
    final schedule = widget.building.getSchedule();

    if (schedule.isEmpty) {
      return Container();
    }

    final now = DateTime.now();
    final currentDay = now.weekday % 7;
    final currentTime = now.hour * 100 + now.minute;

    final todaySchedule = schedule.firstWhere(
      (period) => period.open?.day == currentDay,
      orElse: () => schedule.first,
    );

    String statusText = '';
    if (isOpen) {
      final closeTime = todaySchedule.close?.time ?? '';
      statusText = 'Closes ${_formatTimeSimple(closeTime)}';
    } else {
      final openTime = todaySchedule.open?.time ?? '';
      final openHour = int.tryParse(openTime.substring(0, 2)) ?? 0;
      final openMinute = int.tryParse(openTime.substring(2, 4)) ?? 0;
      final openTimeInt = openHour * 100 + openMinute;

      if (openTimeInt > currentTime) {
        // Opens later today
        statusText = 'Opens ${_formatTimeSimple(openTime)}';
      } else {
        // Opens tomorrow or next available day
        final nextDay = schedule.firstWhere(
          (period) => (period.open?.day ?? 0) > currentDay,
          orElse: () => schedule.first,
        );
        final nextOpenTime = nextDay.open?.time ?? '';
        final nextDayName = _getDayName(nextDay.open?.day ?? 0);
        statusText = 'Opens $nextDayName ${_formatTimeSimple(nextOpenTime)}';
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.concordiaForeground,
                      ),
                      children: [
                        TextSpan(
                          text: isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isOpen
                                ? AppTheme.concordiaGreen
                                : AppTheme.concordiaMaroon,
                          ),
                        ),
                        TextSpan(
                          text: ' · $statusText',
                          style: TextStyle(
                            color: AppTheme.concordiaForeground.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.concordiaForeground.withValues(alpha: 0.6),
                  size: 24,
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              ...schedule.map((period) {
                final dayName = _getDayName(period.open?.day ?? 0);
                final openTime = _formatTimeSimple(period.open?.time ?? '');
                final closeTime = _formatTimeSimple(period.close?.time ?? '');
                final isToday = period.open?.day == currentDay;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: AppTheme.concordiaForeground,
                        ),
                      ),
                      Text(
                        '$openTime - $closeTime',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: AppTheme.concordiaForeground.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  String _getDayName(int day) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[day % 7];
  }

  String _formatTimeSimple(String time) {
    if (time.isEmpty || time.length != 4) return time;
    final hour = int.tryParse(time.substring(0, 2)) ?? 0;
    final minute = time.substring(2, 4);
    final period = hour >= 12 ? 'p.m.' : 'a.m.';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    // Don't show minutes if they're 00
    if (minute == '00') {
      return '$displayHour $period';
    }
    return '$displayHour:$minute $period';
  }
}
