import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that detects user inactivity and triggers callbacks or dialogs after a specified duration.
///
/// Listens for app lifecycle changes (paused & inactive), pointer, keyboard, and scroll events.
/// Can show a dialog or countdown overlay when inactive.
///
/// **Performance Characteristics:**
/// - Main content never rebuilds during countdown updates
/// - Countdown overlay is isolated with its own state management
/// - Timer updates are optimized to prevent unnecessary rebuilds
/// - Event listeners are efficiently managed
///
/// **App Lifecycle Behavior:**
/// - Pauses countdown when app goes to background (paused/inactive).
/// - Shows inactivity dialog (from dialogBuilder) immediately when returning to foreground.
/// - Resets countdown when resume() (available in dialogBuilder parameter) is called (e.g., from dialog "Resume" button).
/// - Requires user acknowledgment to resume after returning to app.
///
/// **Usage Guidelines:**
/// - Use for security-sensitive screens that require user attention
/// - Consider battery impact when using long durations
/// - Avoid using with very short durations (< 10 seconds) for better UX
///
/// **Best Practices:**
/// - Always provide meaningful dialog content
/// - Use appropriate countdown positions for your UI
/// - Handle app lifecycle callbacks appropriately
///
/// **Use Case:**
/// - Accurately tracks user activity time while operating the app
class InactivityDetector extends StatefulWidget {
  /// Default inactivity duration if none specified.
  static const Duration _defaultInactivityDuration = Duration(seconds: 10);

  /// The subtree to monitor for inactivity.
  final Widget child;

  /// Duration of inactivity before triggering [onInactive].
  /// Must be positive and non-zero (validated at runtime).
  /// Recommended minimum: 10 seconds for better user experience.
  final Duration duration;

  /// Callback when inactivity is detected.
  /// Called when the inactivity timer expires.
  final VoidCallback? onInactive;

  /// Optional builder for a dialog to show on inactivity.
  /// The dialog will be non-dismissible and must be closed via the onResume callback.
  /// If not provided, only the [onInactive] callback will be triggered.
  final Widget Function(BuildContext context, VoidCallback onResume)?
  dialogBuilder;

  /// Optional builder for a countdown overlay.
  /// Receives the number of seconds remaining before inactivity.
  /// If not provided, no countdown overlay will be shown.
  final Widget Function(BuildContext context, int secondsRemaining)?
  countdownBuilder;

  /// Position for the countdown overlay. Only used when [countdownBuilder] is provided.
  /// Defaults to [CountdownPosition.topLeft].
  final CountdownPosition countdownPosition;

  /// Callback when app is paused or inactive (backgrounded).
  /// Called immediately when app goes to background.
  final VoidCallback? onAppLifecyclePausedOrInactive;

  /// Constructs an [InactivityDetector] widget that monitors user inactivity within its widget subtree.
  ///
  /// This widget provides automatic detection of user inactivity based on the specified [duration].
  /// When inactivity is detected, it can trigger a callback, display a custom dialog, and/or show a countdown overlay.
  ///
  /// See parameters below for customization options.
  ///
  /// Parameters:
  /// - [child]: The widget subtree to monitor for inactivity. Can be your main app widget or only for specific screen. This parameter is required and must not be null.
  /// - [duration]: The duration of inactivity before triggering [onInactive]. Must be positive and non-zero. Defaults to 10 seconds if not specified.
  /// - [onInactive]: Optional callback that is called when the inactivity timer expires.
  /// - [dialogBuilder]: Optional builder for a dialog to show when inactivity is detected. The dialog will be non-dismissible and must be closed via the provided [onResume] callback. If not provided, only [onInactive] will be triggered.
  /// - [countdownBuilder]: Optional builder for a countdown overlay. Receives the number of seconds remaining before inactivity. If not provided, no countdown overlay will be shown.
  /// - [countdownPosition]: The position for the countdown overlay. Only used when [countdownBuilder] is provided. Defaults to [CountdownPosition.topLeft].
  /// - [onAppLifecyclePausedOrInactive]: Optional callback that is called immediately when the app goes to the background (paused or inactive).
  ///
  /// Example usage:
  /// ```dart
  /// InactivityDetector(
  ///   duration: Duration(minutes: 1),
  ///   onInactive: _pauseTimer,
  ///   dialogBuilder: (context, onResume) => AlertDialog(
  ///     title: Text('Inactive'),
  ///     content: Text('You have been inactive.'),
  ///     actions: [
  ///       TextButton(
  ///         onPressed: () {
  ///           onResume();
  ///           _resumeTimer();
  ///         },
  ///         child: Text('Resume'),
  ///       ),
  ///     ],
  ///   ),
  ///   onAppLifecyclePausedOrInactive: () {
  ///     _pauseTimer();
  ///   },
  ///   countdownBuilder: (context, secondsLeft) => Text('$secondsLeft'),
  ///   countdownPosition: CountdownPosition.topRight,
  ///   child: MyApp(),
  /// )
  /// ```
  const InactivityDetector({
    super.key,
    required this.child,
    this.duration = _defaultInactivityDuration,
    this.onInactive,
    this.dialogBuilder,
    this.countdownBuilder,
    this.countdownPosition = CountdownPosition.topLeft,
    this.onAppLifecyclePausedOrInactive,
  });

  /// Use by [InactivityAwareTextControllerMixin] as a listener to reset the inactivity timer.
  /// Can also be called manually to indicate user activity.
  /// This method is thread-safe and handles null instances gracefully.
  static void triggerUserInteraction() {
    _InactivityDetectorState? instance = _currentInstance;
    if (instance != null && !instance._isInactivityDialogVisible) {
      instance._onUserActivityDetected();
    }
  }

  /// Static reference to the current instance for global access.
  /// Used by [triggerUserInteraction] to reset timers from anywhere in the app.
  static _InactivityDetectorState? _currentInstance;

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

/// State class for [InactivityDetector] that manages timers, event listeners, and lifecycle.
/// This class is optimized to prevent unnecessary rebuilds of the main content.
///
/// **State Management:**
/// - Main content state is isolated from countdown state
/// - Lifecycle state is managed efficiently
/// - Dialog state is handled separately
/// - Timer state is optimized for performance
class _InactivityDetectorState extends State<InactivityDetector>
    with WidgetsBindingObserver {
  // Timer and state management
  Timer? _timer;
  bool _isInactivityDialogVisible = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  static const Duration _maxDuration = Duration(hours: 24);

  // Cached values for performance optimization
  late final bool _hasCountdownOverlay;
  late final bool _hasInactivityDialog;

  // Key for countdown overlay to force rebuild when needed
  Key _countdownKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _validateAndCacheProperties();
    _setupInstanceReference();
    _setupLifecycleObserver();
    _setupEventListeners();
    _startInactivityTimer();
  }

  /// Validates widget properties and caches frequently accessed values.
  /// Throws [ArgumentError] if validation fails.
  void _validateAndCacheProperties() {
    if (widget.duration.inMilliseconds <= 0) {
      throw ArgumentError('Duration must be positive and non-zero');
    }
    if (widget.duration.inMilliseconds > _maxDuration.inMilliseconds) {
      throw ArgumentError('Duration cannot exceed 24 hours');
    }
    _hasCountdownOverlay = widget.countdownBuilder != null;
    _hasInactivityDialog = widget.dialogBuilder != null;
  }

  /// Sets up the static instance reference for global access.
  /// This allows [triggerUserInteraction] to work from anywhere in the app.
  void _setupInstanceReference() {
    InactivityDetector._currentInstance = this;
  }

  /// Sets up lifecycle observer for app state changes.
  /// Registers this widget to receive app lifecycle notifications.
  void _setupLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Sets up global event listeners for user activity detection.
  /// Listens for pointer and keyboard events globally.
  void _setupEventListeners() {
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  /// Starts the inactivity timer with the configured duration.
  /// This timer will trigger [onInactive] callback when it expires.
  void _startInactivityTimer() {
    _timer = Timer(widget.duration, _onInactivityTimeout);
  }

  /// Restarts the inactivity timer with the configured duration.
  /// Also resets the countdown overlay if present.
  void _restartInactivityTimer() {
    _timer?.cancel();
    _startInactivityTimer();

    // Reset countdown overlay if present
    if (_hasCountdownOverlay) {
      setState(() {
        _countdownKey = UniqueKey();
      });
    }
  }

  /// Handles user activity by restarting the inactivity timer.
  /// Called when any user interaction is detected.
  void _onUserActivityDetected() {
    if (_isInactivityDialogVisible || !mounted) return;
    _restartInactivityTimer();
  }

  /// Handles pointer events to detect user interaction.
  /// Called for all pointer events globally.
  void _onPointerEvent(PointerEvent event) {
    if (!_isInactivityDialogVisible && mounted) _onUserActivityDetected();
  }

  /// Handles keyboard events to detect user interaction.
  /// Called for all keyboard events globally.
  bool _onKeyEvent(KeyEvent event) {
    if (!_isInactivityDialogVisible && mounted) _onUserActivityDetected();
    return false;
  }

  /// Handles scroll notifications as user activity.
  /// Called when scroll events occur in the widget tree.
  bool _onScrollNotification(ScrollNotification notification) {
    if (!_isInactivityDialogVisible && mounted) _onUserActivityDetected();
    return false;
  }

  @override
  void dispose() {
    _cleanupInstanceReference();
    _cleanupLifecycleObserver();
    _cleanupEventListeners();
    _cleanupTimer();
    super.dispose();
  }

  /// Cleans up the static instance reference.
  /// Ensures no memory leaks from static references.
  void _cleanupInstanceReference() {
    if (InactivityDetector._currentInstance == this) {
      InactivityDetector._currentInstance = null;
    }
  }

  /// Removes lifecycle observer.
  /// Prevents memory leaks and unnecessary callbacks.
  void _cleanupLifecycleObserver() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Removes global event listeners.
  /// Ensures proper cleanup of global event handlers.
  void _cleanupEventListeners() {
    try {
      WidgetsBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
      HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    } catch (e) {
      debugPrint('Error cleaning up event listeners: $e');
    }
  }

  /// Cancels and cleans up the inactivity timer.
  /// Prevents timer leaks and unnecessary callbacks.
  void _cleanupTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Handles app lifecycle changes to pause or resume inactivity detection.
  /// Manages timer state based on app lifecycle and shows dialogs when appropriate.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!mounted) return;

    setState(() => _lifecycleState = state);

    /// Handle app becoming inactive (e.g., switching to another app or receiving a call)
    /// Cancel the inactivity timer and notify listeners that the app is paused/inactive
    if (state == AppLifecycleState.inactive) {
      if (_timer?.isActive == true) _timer?.cancel();
      widget.onAppLifecyclePausedOrInactive?.call();
    }
    if (state == AppLifecycleState.resumed) {
      if (_timer?.isActive == true) _timer?.cancel();

      /// When app resumes, show dialog immediately.
      /// This ensures user sees the dialog when returning to the app
      if (_hasInactivityDialog && !_isInactivityDialogVisible) {
        _displayInactivityDialog();
      }
    }
  }

  /// Shows the inactivity dialog with proper error handling.
  /// Manages dialog state and handles user interaction.
  void _displayInactivityDialog() {
    if (!mounted || _isInactivityDialogVisible) return;

    _isInactivityDialogVisible = true;
    showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) =>
                  widget.dialogBuilder!(context, _dismissInactivityDialog),
        )
        .then((_) {
          if (mounted) {
            _isInactivityDialogVisible = false;
            _restartInactivityTimer();
          }
        })
        .catchError((e) {
          debugPrint('Error showing inactivity dialog: $e');
          if (mounted) {
            _isInactivityDialogVisible = false;
            _restartInactivityTimer();
          }
        });
  }

  /// Handles inactivity timeout by triggering callbacks and showing dialog.
  /// Called when the inactivity timer expires.
  void _onInactivityTimeout() {
    if (!mounted) return;

    widget.onInactive?.call();

    if (_hasInactivityDialog && !_isInactivityDialogVisible) {
      _displayInactivityDialog();
    }
  }

  /// Dismisses the inactivity dialog and restarts the timer.
  /// Called when user clicks the resume button in the dialog.
  void _dismissInactivityDialog() {
    if (!mounted) return;

    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      debugPrint('Error dismissing inactivity dialog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LifecycleStateProvider(
      lifecycleState: _lifecycleState,
      child: _buildEventListeners(
        child: _buildCountdownOverlay(child: widget.child),
      ),
    );
  }

  /// Builds the countdown overlay if provided.
  /// Returns the child directly if no countdown overlay is configured.
  Widget _buildCountdownOverlay({required Widget child}) {
    if (!_hasCountdownOverlay) return child;

    return Stack(
      children: [
        child,
        _CountdownOverlay(
          key: _countdownKey,
          countdownBuilder: widget.countdownBuilder!,
          position: widget.countdownPosition,
          initialSeconds: widget.duration.inSeconds,
          lifecycleState: _lifecycleState,
        ),
      ],
    );
  }

  /// Wraps the child with event listeners for user activity detection.
  /// Provides comprehensive user interaction detection through multiple event types.
  Widget _buildEventListeners({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onUserActivityDetected,
        child: Listener(
          onPointerDown: (_) => _onUserActivityDetected(),
          onPointerMove: (_) => _onUserActivityDetected(),
          onPointerHover: (_) => _onUserActivityDetected(),
          child: child,
        ),
      ),
    );
  }
}

/// Enum defining the available positions for the countdown overlay.
enum CountdownPosition {
  /// Top-left corner of the screen
  topLeft,

  /// Top-right corner of the screen
  topRight,

  /// Bottom-left corner of the screen
  bottomLeft,

  /// Bottom-right corner of the screen
  bottomRight,

  /// Center of the screen
  center,
}

/// Mixin for creating a [TextEditingController] that notifies [InactivityDetector]
/// of user interaction on every text change. Use this instead of a regular controller
/// to ensure typing resets inactivity timers.
///
/// **Usage:**
/// ```dart
/// class MyWidgetState extends State<MyWidget> with InactivityAwareTextControllerMixin {
///   late final TextEditingController controller;
///
///   @override
///   void initState() {
///     super.initState();
///     controller = createInactivityAwareTextController();
///   }
/// }
/// ```
mixin InactivityAwareTextControllerMixin<T extends StatefulWidget> on State<T> {
  /// Returns a [TextEditingController] that triggers user interaction on text change.
  /// This controller will automatically reset the inactivity timer whenever the user types.
  TextEditingController createInactivityAwareTextController() {
    final controller = TextEditingController();
    controller.addListener(InactivityDetector.triggerUserInteraction);
    return controller;
  }
}

/// Private widget to propagate the current [AppLifecycleState] down the widget tree.
/// This allows child widgets to react to app lifecycle changes without direct access
/// to the main [InactivityDetector] state.
class _LifecycleStateProvider extends InheritedWidget {
  final AppLifecycleState lifecycleState;

  const _LifecycleStateProvider({
    required this.lifecycleState,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LifecycleStateProvider oldWidget) =>
      oldWidget.lifecycleState != lifecycleState;
}

/// Private widget that manages countdown state independently to prevent main content rebuilds.
/// This widget handles its own timer and positioning, ensuring that countdown updates
/// don't cause the main application content to rebuild.
///
/// **Performance Benefits:**
/// - Isolated state management prevents main content rebuilds
/// - RepaintBoundary ensures only countdown widget repaints
/// - Efficient timer management with proper cleanup
class _CountdownOverlay extends StatefulWidget {
  final Widget Function(BuildContext context, int secondsRemaining)
  countdownBuilder;
  final CountdownPosition position;
  final int initialSeconds;
  final AppLifecycleState lifecycleState;

  const _CountdownOverlay({
    super.key,
    required this.countdownBuilder,
    required this.position,
    required this.initialSeconds,
    required this.lifecycleState,
  });

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

/// State class for [_CountdownOverlay] that manages countdown timer and positioning.
/// This class is completely isolated from the main [InactivityDetector] state.
class _CountdownOverlayState extends State<_CountdownOverlay> {
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isCountdownPaused = false;
  static const double _overlayMargin = 16.0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startCountdownTimer();
  }

  @override
  void didUpdateWidget(_CountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle lifecycle state changes
    if (oldWidget.lifecycleState != widget.lifecycleState) {
      _onLifecycleStateChanged(widget.lifecycleState);
    }

    // Handle initial seconds changes (when timer is reset)
    if (oldWidget.initialSeconds != widget.initialSeconds) {
      _resetCountdownTimer();
    }
  }

  /// Handles app lifecycle state changes to pause countdown timer.
  /// Pauses countdown when app goes to background.
  void _onLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.resumed) {
      _pauseCountdownTimer();
    }
  }

  /// Starts the countdown timer that updates every second.
  /// Only starts if countdown is not currently paused.
  void _startCountdownTimer() {
    if (_isCountdownPaused) return;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted || _isCountdownPaused) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      }
    });
  }

  /// Pauses the countdown timer and cancels the current timer.
  void _pauseCountdownTimer() {
    _isCountdownPaused = true;
    _timer?.cancel();
  }

  /// Resets the countdown timer to the initial value and starts it.
  /// Used when the main inactivity timer is reset.
  void _resetCountdownTimer() {
    _timer?.cancel();
    _remainingSeconds = widget.initialSeconds;
    _isCountdownPaused = false;
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _positionCountdownWidget(
      RepaintBoundary(
        child: widget.countdownBuilder(context, _remainingSeconds),
      ),
    );
  }

  /// Positions the countdown widget based on the selected position.
  /// Handles safe area margins and provides consistent positioning across devices.
  Widget _positionCountdownWidget(Widget countdownWidget) {
    switch (widget.position) {
      case CountdownPosition.topLeft:
        return Positioned(
          top: MediaQuery.of(context).padding.top + _overlayMargin,
          left: MediaQuery.of(context).padding.left + _overlayMargin,
          child: countdownWidget,
        );
      case CountdownPosition.topRight:
        return Positioned(
          top: MediaQuery.of(context).padding.top + _overlayMargin,
          right: MediaQuery.of(context).padding.right + _overlayMargin,
          child: countdownWidget,
        );
      case CountdownPosition.bottomLeft:
        return Positioned(
          bottom: MediaQuery.of(context).padding.bottom + _overlayMargin,
          left: MediaQuery.of(context).padding.left + _overlayMargin,
          child: countdownWidget,
        );
      case CountdownPosition.bottomRight:
        return Positioned(
          bottom: MediaQuery.of(context).padding.bottom + _overlayMargin,
          right: MediaQuery.of(context).padding.right + _overlayMargin,
          child: countdownWidget,
        );
      case CountdownPosition.center:
        return Center(child: countdownWidget);
    }
  }
}
