import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HydrationReminderPage extends StatefulWidget {
  const HydrationReminderPage({super.key});

  @override
  State<HydrationReminderPage> createState() => _HydrationReminderPageState();
}

class _HydrationReminderPageState extends State<HydrationReminderPage> {
  final _intervalCtrl = TextEditingController(); // minutes
  final _targetCtrl = TextEditingController();   // cups/day
  Timer? _timer;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intervalCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final interval = p.getInt('hydration_interval') ?? 60;
    final target = p.getInt('hydration_target') ?? 8;
    final enabled = p.getBool('hydration_enabled') ?? false;
    setState(() {
      _intervalCtrl.text = interval.toString();
      _targetCtrl.text = target.toString();
      _enabled = enabled;
    });
    if (enabled) _startTimer(interval);
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    final interval = int.tryParse(_intervalCtrl.text) ?? 60;
    final target = int.tryParse(_targetCtrl.text) ?? 8;
    await p.setInt('hydration_interval', interval);
    await p.setInt('hydration_target', target);
    await p.setBool('hydration_enabled', _enabled);
  }

  void _startTimer(int minutes) {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time to drink water 💧')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hydration Reminder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _enabled,
            title: const Text('Enable reminders'),
            onChanged: (v) async {
              setState(() => _enabled = v);
              await _savePrefs();
              final interval = int.tryParse(_intervalCtrl.text) ?? 60;
              if (v) {
                _startTimer(interval);
              } else {
                _timer?.cancel();
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _intervalCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Reminder interval (minutes)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _savePrefs(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target cups per day',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _savePrefs(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final interval = int.tryParse(_intervalCtrl.text) ?? 60;
              _savePrefs();
              if (_enabled) _startTimer(interval);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✓ Hydration settings saved'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
