import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:flutter/material.dart";
import "package:flutter_google_maps_webservices/places.dart";

class OpeningHoursWidget extends StatefulWidget {
  final Building building;

  const OpeningHoursWidget({super.key, required this.building});

  @override
  State<OpeningHoursWidget> createState() => _OpeningHoursWidgetState();
}

class _OpeningHoursWidgetState extends State<OpeningHoursWidget> {
  bool _isExpanded = false;

  @override
  Widget build(final BuildContext context) {
    final schedule = widget.building.getSchedule();

    if (schedule.isEmpty) {
      return Container();
    }

    final isOpen = widget.building.isOpen();
    final currentDay = DateTime.now().weekday % 7;
    final statusText = _getStatusText(isOpen, schedule, currentDay);

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
                          text: isOpen ? "Open" : "Closed",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isOpen
                                ? AppTheme.concordiaGreen
                                : AppTheme.concordiaMaroon,
                          ),
                        ),
                        TextSpan(
                          text: " · $statusText",
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
              ...schedule.map((final period) {
                final dayName = _getDayName(period.open?.day ?? 0);
                final openTime = _formatTimeSimple(period.open?.time ?? "");
                final closeTime = _formatTimeSimple(period.close?.time ?? "");
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
                        "$openTime - $closeTime",
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
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusText(
    final bool isOpen,
    final List<OpeningHoursPeriod> schedule,
    final int currentDay,
  ) {
    final todaySchedule = _getTodaySchedule(schedule, currentDay);

    if (isOpen) {
      return _getClosingText(todaySchedule);
    }

    return _getOpeningText(schedule, currentDay, todaySchedule);
  }

  OpeningHoursPeriod _getTodaySchedule(
    final List<OpeningHoursPeriod> schedule,
    final int currentDay,
  ) {
    return schedule.firstWhere(
      (final period) => period.open?.day == currentDay,
      orElse: () => schedule.first,
    );
  }

  String _getClosingText(final OpeningHoursPeriod todaySchedule) {
    final closeTime = todaySchedule.close?.time ?? "";
    return "Closes ${_formatTimeSimple(closeTime)}";
  }

  String _getOpeningText(
    final List<OpeningHoursPeriod> schedule,
    final int currentDay,
    final OpeningHoursPeriod todaySchedule,
  ) {
    final openTime = todaySchedule.open?.time ?? "";
    final currentTime = DateTime.now().hour * 100 + DateTime.now().minute;

    if (_opensLaterToday(openTime, currentTime)) {
      return "Opens ${_formatTimeSimple(openTime)}";
    }

    return _getNextOpeningText(schedule, currentDay);
  }

  bool _opensLaterToday(final String openTime, final int currentTime) {
    if (openTime.isEmpty || openTime.length != 4) return false;
    final openHour = int.tryParse(openTime.substring(0, 2)) ?? 0;
    final openMinute = int.tryParse(openTime.substring(2, 4)) ?? 0;
    final openTimeInt = openHour * 100 + openMinute;
    return openTimeInt > currentTime;
  }

  String _getNextOpeningText(
    final List<OpeningHoursPeriod> schedule,
    final int currentDay,
  ) {
    final nextDay = schedule.firstWhere(
      (final period) => (period.open?.day ?? 0) > currentDay,
      orElse: () => schedule.first,
    );
    final nextOpenTime = nextDay.open?.time ?? "";
    final nextDayName = _getDayName(nextDay.open?.day ?? 0);
    return "Opens $nextDayName ${_formatTimeSimple(nextOpenTime)}";
  }

  String _getDayName(final int day) {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[day % 7];
  }

  String _formatTimeSimple(final String time) {
    if (time.isEmpty || time.length != 4) return time;
    final hour = int.tryParse(time.substring(0, 2)) ?? 0;
    final minute = time.substring(2, 4);
    final period = hour >= 12 ? "p.m." : "a.m.";

    int displayHour;
    if (hour > 12) {
      displayHour = hour - 12;
    } else if (hour == 0) {
      displayHour = 12;
    } else {
      displayHour = hour;
    }

    // Don't show minutes if they're 00
    if (minute == "00") {
      return "$displayHour $period";
    }
    return "$displayHour:$minute $period";
  }
}
