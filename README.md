# Inactivity Detector

A package to detect user inactivity and triggers callbacks after a specified duration.

Most suitable for scenarios that require accurate tracking of user activity time while doing some operation within the app.

![Image](./screenshot/demo.gif?raw=true)

---

## Features

- User inactivity detection when there are no taps, scroll, keyboard input, and apps goes to background (optional)
- Customizable inactivity time window Duration
- Custom callbacks or business logic when inactivity is detected
- Provide optional countdown timer overlay (helpful for debugging)
---

## Getting Started

Add the package to your `pubspec.yaml`:
```yaml
dependencies:
  inactivity_detector: ^0.0.1
```

## Usage

InactivityDetector provide some configuration:
- `child`: The widget subtree to monitor for inactivity. Can be your main app widget or only for specific screen. This parameter is required and must not be null.
- `duration`: The duration of inactivity before triggering `onInactive`. Must be positive and non-zero. Defaults to 10 seconds if not specified.
- `onInactive`: Optional callback that is called when the inactivity timer expires.
- `dialogBuilder`: Optional builder for a dialog to show when inactivity is detected. The dialog will be non-dismissible and must be closed via the provided `onResume` callback. If not provided, only `onInactive` will be triggered.
- `countdownBuilder`: Optional builder for a countdown overlay. Receives the number of seconds remaining before inactivity. If not provided, no countdown overlay will be shown.
- `countdownPosition`: The position for the countdown overlay. Only used when `countdownBuilder` is provided. Defaults to `CountdownPosition.topLeft`.
- `onAppLifecyclePausedOrInactive`: Optional callback that is called immediately when the app goes to the background (paused or inactive).
  
Example
```dart
import 'package:inactivity_detector/inactivity_detector.dart';

...
InactivityDetector(
  duration: Duration(minutes: 1), 
  onInactive: _pauseTimer, //_pauseTimer is your function to pause the timer
  dialogBuilder: (context, onResume) => AlertDialog( 
    title: Text('Inactive'),
    content: Text('You have been inactive.'),
    actions: [
      TextButton(
        onPressed: () {
          onResume();
          _resumeTimer(); //_resumeTimer() is your function to resume the timer
        },
        child: Text('Resume'),
      ),
    ],
  ),
  onAppLifecyclePausedOrInactive: () {
    _pauseTimer(); // optional call _pauseTimer when app goes to background
  },
  countdownBuilder: (context, secondsLeft) => Text('$secondsLeft'),
  countdownPosition: CountdownPosition.topRight,
  child: MyApp(),
)
...

```

`InactivityAwareTextControllerMixin` is a mixin that can be used with your `State` class to automatically reset the inactivity timer whenever the user interacts with a `TextField` (e.g., typing, pasting, or editing text). This is useful if you want text input to count as user activity for inactivity detection.

#### How to use

1. Add the mixin to your `State` class.
2. Use the provided `createInactivityAwareTextController` instead of a regular `TextEditingController`.
3. Pass the controller to your `TextField` widget.
  
Example
```dart
import 'package:inactivity_detector/inactivity_detector.dart';

...
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with InactivityAwareTextControllerMixin {

  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = createInactivityAwareTextController(); //available from InactivityAwareTextControllerMixin
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome')),
      body: Center(
        child: SingleChildScrollView(
          child: Form(
            child: Column(
              children: [TextField(controller: _textController)],
            ),
          ),
        ),
      ),
    );
  }


}
...

```