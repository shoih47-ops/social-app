import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/fcm_service.dart';

const int _defaultReminderMinutes = 19 * 60;

class _ReminderTimeOption {
  final String id;
  final String label;
  final int minutes;

  const _ReminderTimeOption({
    required this.id,
    required this.label,
    required this.minutes,
  });
}

const List<_ReminderTimeOption> _reminderTimeOptions = [
  _ReminderTimeOption(
    id: 'morning',
    label: 'Morning (9:00 AM)',
    minutes: 9 * 60,
  ),
  _ReminderTimeOption(
    id: 'afternoon',
    label: 'Afternoon (1:00 PM)',
    minutes: 13 * 60,
  ),
  _ReminderTimeOption(
    id: 'evening',
    label: 'Evening (7:00 PM)',
    minutes: 19 * 60,
  ),
  _ReminderTimeOption(id: 'night', label: 'Night (9:00 PM)', minutes: 21 * 60),
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  int _readReminderMinutes(Map<String, dynamic>? data) {
    final value = data?['dailyReminderTimeMinutes'];
    if (value is num) {
      final minutes = value.toInt();
      if (minutes >= 0 && minutes < 24 * 60) return minutes;
    }
    return _defaultReminderMinutes;
  }

  String _reminderTimeLabel(Map<String, dynamic>? data) {
    final optionId = (data?['dailyReminderTimeOption'] ?? 'evening')
        .toString();
    if (optionId == 'custom') {
      return _formatReminderMinutes(_readReminderMinutes(data));
    }

    return _reminderTimeOptions
        .firstWhere(
          (option) => option.id == optionId,
          orElse: () => _reminderTimeOptions[2],
        )
        .label;
  }

  String _formatReminderMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return 'Custom Time ($displayHour:${minute.toString().padLeft(2, '0')} $period)';
  }

  Future<void> _saveReminderTime({
    required String userId,
    required String optionId,
    required int minutes,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'dailyReminderTimeOption': optionId,
      'dailyReminderTimeMinutes': minutes,
      'dailyReminderTimeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _chooseReminderTime(
    BuildContext context,
    String userId,
    Map<String, dynamic>? data,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in _reminderTimeOptions)
                ListTile(
                  title: Text(option.label),
                  onTap: () async {
                    await _saveReminderTime(
                      userId: userId,
                      optionId: option.id,
                      minutes: option.minutes,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ListTile(
                title: const Text('Custom Time'),
                onTap: () async {
                  final currentMinutes = _readReminderMinutes(data);
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: currentMinutes ~/ 60,
                      minute: currentMinutes % 60,
                    ),
                  );
                  if (picked == null) return;

                  await _saveReminderTime(
                    userId: userId,
                    optionId: 'custom',
                    minutes: picked.hour * 60 + picked.minute,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final remindersEnabled =
                    data?['dailyRemindersEnabled'] == true;

                return Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_none),
                      title: const Text('Daily reminders'),
                      subtitle: const Text('Gentle daily prompts from Journa'),
                      value: remindersEnabled,
                      onChanged: (enabled) async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set({
                              'dailyRemindersEnabled': enabled,
                              'dailyRemindersUpdatedAt':
                                  FieldValue.serverTimestamp(),
                              if (enabled &&
                                  data?['dailyReminderTimeMinutes'] == null)
                                'dailyReminderTimeMinutes':
                                    _defaultReminderMinutes,
                              if (enabled &&
                                  data?['dailyReminderTimeOption'] == null)
                                'dailyReminderTimeOption': 'evening',
                            }, SetOptions(merge: true));

                        if (enabled) {
                          await FcmService.instance.syncTokenForCurrentUser();
                        }
                      },
                    ),
                    ListTile(
                      enabled: remindersEnabled,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Reminder Time'),
                      subtitle: Text(_reminderTimeLabel(data)),
                      onTap: remindersEnabled
                          ? () => _chooseReminderTime(context, user.uid, data)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;

              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
