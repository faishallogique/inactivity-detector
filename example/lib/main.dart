import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inactivity_detector/inactivity_detector.dart';

void main() {
  runApp(const InactivityDetectorDemoApp());
}

///
/// Main application widget that demonstrates the inactivity_detector package.
///
class InactivityDetectorDemoApp extends StatelessWidget {
  const InactivityDetectorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inactivity Detector Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // handles edge-to-edge display with SafeArea
      builder: (_, child) => SafeArea(top: false, bottom: true, child: child!),
      home: const InactivityDetectorDemo(),
    );
  }
}

///
/// Demo screen that showcases all features of the inactivity_detector package.
///
class InactivityDetectorDemo extends StatefulWidget {
  const InactivityDetectorDemo({super.key});

  @override
  State<InactivityDetectorDemo> createState() => _InactivityDetectorDemoState();
}

class _InactivityDetectorDemoState extends State<InactivityDetectorDemo>
    with InactivityAwareTextControllerMixin {
  // Controllers for text fields
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  // State variables
  bool _isTimerPaused = false;
  int _inactivityCount = 0;
  String _lastActivity = 'None';
  int _timerCounter = 0; // Timer counter that resets on activity
  Timer? _timer; // Timer to track elapsed time

  // Inactivity duration - can be customized
  static const Duration _inactivityDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    // Initialize text controllers with inactivity awareness
    _nameController = createInactivityAwareTextController();
    _emailController = createInactivityAwareTextController();
    // Start the timer
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  ///
  /// Starts the timer to increment the counter.
  ///
  void _startTimer() {
    _timer?.cancel(); // Cancel existing timer if any
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isTimerPaused) {
        setState(() {
          _timerCounter++;
        });
      }
    });
  }

  ///
  /// Handles inactivity detection - called when user becomes inactive.
  ///
  void _handleInactivity() {
    setState(() {
      _isTimerPaused = true;
      _inactivityCount++;
      _lastActivity = 'Inactivity Detected';
    });
  }

  ///
  /// Resumes the session after inactivity.
  ///
  void _resumeSession() {
    setState(() {
      _isTimerPaused = false;
      _lastActivity = 'Session Resumed';
    });
  }

  ///
  /// Records user activity for demonstration purposes.
  ///
  void _recordActivity(String activity) {
    setState(() {
      _lastActivity = activity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InactivityDetector(
      // Configure inactivity detection
      duration: _inactivityDuration,
      onInactive: _handleInactivity,
      onAppLifecyclePausedOrInactive: _handleInactivity,
      // Custom dialog builder for inactivity detection
      dialogBuilder: (context, onResume) =>
          _buildInactivityDialog(context, onResume),

      // Custom countdown builder for visual feedback/debugging
      countdownBuilder: (context, secondsLeft) =>
          _buildCountdownOverlay(secondsLeft),
      countdownPosition: CountdownPosition.topRight,

      // Main app content
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inactivity Detector Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          elevation: 2,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildBody(),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  ///
  /// Builds the main body content with various interactive elements.
  ///
  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status card showing current state
        _buildStatusCard(),
        const SizedBox(height: 24),

        // Interactive form section
        _buildFormSection(),
        const SizedBox(height: 24),

        // Activity buttons section
        _buildActivityButtons(),
        const SizedBox(height: 24),

        // Information section
        _buildInfoSection(),
      ],
    );
  }

  ///
  /// Builds a status card showing current inactivity state.
  ///
  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isTimerPaused ? Icons.pause_circle : Icons.play_circle,
                  color: _isTimerPaused ? Colors.orange : Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTimerPaused ? 'Session Paused' : 'Session Active',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Inactivity Count', '$_inactivityCount'),
            _buildStatusRow('Last Activity', _lastActivity),
            _buildStatusRow('Timer Counter', '$_timerCounter seconds'),
          ],
        ),
      ),
    );
  }

  ///
  /// Builds a status row for the status card.
  ///
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  ///
  /// Builds the form section with inactivity-aware text controllers.
  ///
  Widget _buildFormSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interactive Form',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (_) => _recordActivity('Name field edited'),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              onChanged: (_) => _recordActivity('Email field edited'),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ],
        ),
      ),
    );
  }

  ///
  /// Builds interactive activity buttons.
  ///
  Widget _buildActivityButtons() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Buttons',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActivityButton(
                  'Tap Me',
                  Icons.touch_app,
                  () => _recordActivity('Button tapped'),
                ),
                _buildActivityButton(
                  'Refresh',
                  Icons.refresh,
                  () => _recordActivity('Refresh action'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ///
  /// Builds an individual activity button.
  ///
  Widget _buildActivityButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  ///
  /// Builds information section about the demo.
  ///
  Widget _buildInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How It Works',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              'Inactivity Duration',
              '${_inactivityDuration.inSeconds} seconds',
              Icons.timer,
            ),
            _buildInfoItem(
              'Countdown Position',
              'Top Right',
              Icons.location_on,
            ),
            _buildInfoItem(
              'Text Input Awareness',
              'Enabled',
              Icons.text_fields,
            ),
            _buildInfoItem('App Lifecycle', 'Monitored', Icons.phone_android),
          ],
        ),
      ),
    );
  }

  ///
  /// Builds an individual info item.
  ///
  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  ///
  /// Builds the floating action button.
  ///
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _recordActivity('FAB pressed'),
      icon: const Icon(Icons.add),
      label: const Text('Activity'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  ///
  /// Builds the inactivity dialog.
  ///
  Widget _buildInactivityDialog(BuildContext context, VoidCallback onResume) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.timer_off, color: Colors.orange, size: 28),
          const SizedBox(width: 8),
          const Text('Session Paused'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have been inactive for a while.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Your session has been paused to ensure security.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onResume();
            _resumeSession();
          },
          child: const Text('Resume Session'),
        ),
      ],
    );
  }

  ///
  /// Builds the countdown overlay.
  ///
  Widget _buildCountdownOverlay(int secondsLeft) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: secondsLeft <= 3 ? Colors.red : Colors.blue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            secondsLeft <= 3 ? Icons.warning : Icons.timer,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            child: Text('$secondsLeft'),
          ),
        ],
      ),
    );
  }
}
