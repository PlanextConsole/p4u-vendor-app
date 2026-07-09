import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class AvailabilityPage extends ConsumerStatefulWidget {
  const AvailabilityPage({super.key});

  @override
  ConsumerState<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends ConsumerState<AvailabilityPage> {
  static const days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  static const times = [
    '06:00 AM',
    '07:00 AM',
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
    '08:00 PM',
    '09:00 PM'
  ];

  late List<Map<String, dynamic>> schedule = _defaults();
  bool loaded = false;
  bool changed = false;

  List<Map<String, dynamic>> _defaults() => List.generate(
      7,
      (i) => {
            'day_of_week': i,
            'is_available': i >= 1 && i <= 6,
            'time_slots': i >= 1 && i <= 6
                ? [
                    {'start': '09:00 AM', 'end': '06:00 PM'}
                  ]
                : [],
          });

  Future<void> _load() async {
    if (loaded) return;
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    final rows =
        await ref.read(vendorRepositoryProvider).availability(vendorId);
    if (rows.isNotEmpty) {
      final defaults = _defaults();
      for (final row in rows) {
        final idx = row['day_of_week'] as int;
        defaults[idx] = {
          'day_of_week': idx,
          'is_available': row['is_available'] == true,
          'time_slots': row['time_slots'] is List ? row['time_slots'] : [],
        };
      }
      schedule = defaults;
    }
    loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    return VendorScaffold(
      title: 'Availability',
      actions: [
        IconButton(
          onPressed: changed ? _save : null,
          icon: const Icon(Icons.save_rounded),
        ),
      ],
      child: FutureBuilder(
        future: _load(),
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                  'Set your weekly schedule. Customers can only book when you are available.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ...schedule.map((day) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Switch(
                                  value: day['is_available'] == true,
                                  onChanged: (v) =>
                                      _mutate(() => day['is_available'] = v)),
                              Expanded(
                                  child: Text(days[day['day_of_week']],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              if (day['is_available'] == true)
                                TextButton.icon(
                                    onPressed: () => _mutate(() =>
                                        (day['time_slots'] as List).add({
                                          'start': '09:00 AM',
                                          'end': '05:00 PM'
                                        })),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add Slot')),
                            ],
                          ),
                          if (day['is_available'] == true)
                            ...(day['time_slots'] as List)
                                .asMap()
                                .entries
                                .map((entry) {
                              final slot =
                                  Map<String, dynamic>.from(entry.value);
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 48, bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: _TimeDrop(
                                            value: slot['start'],
                                            onChanged: (v) => _mutate(() =>
                                                (day['time_slots']
                                                        as List)[entry.key]
                                                    ['start'] = v))),
                                    const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 8),
                                        child: Text('to')),
                                    Expanded(
                                        child: _TimeDrop(
                                            value: slot['end'],
                                            onChanged: (v) => _mutate(() =>
                                                (day['time_slots']
                                                        as List)[entry.key]
                                                    ['end'] = v))),
                                    IconButton(
                                        onPressed: () => _mutate(() =>
                                            (day['time_slots'] as List)
                                                .removeAt(entry.key)),
                                        icon: const Icon(
                                            Icons.delete_outline_rounded)),
                                  ],
                                ),
                              );
                            })
                          else
                            const Padding(
                                padding: EdgeInsets.only(left: 48),
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Not available',
                                        style:
                                            TextStyle(color: Colors.black54)))),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _mutate(VoidCallback fn) => setState(() {
        fn();
        changed = true;
      });

  Future<void> _save() async {
    final vendorId = ref.read(vendorIdProvider);
    if (vendorId == null) return;
    await ref
        .read(vendorRepositoryProvider)
        .saveAvailability(vendorId, schedule);
    setState(() => changed = false);
  }
}

class _TimeDrop extends StatelessWidget {
  const _TimeDrop({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: _AvailabilityPageState.times
          .map((t) => DropdownMenuItem(
              value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
