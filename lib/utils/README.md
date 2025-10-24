# Utils Directory

This directory contains utility classes and helper functions used throughout the app.

## Files

### `navigation_helper.dart`
A utility class for safe navigation throughout the app. Provides:
- Safe screen navigation with error handling
- Modal bottom sheet handling
- Navigation replacement methods
- Safe pop functionality

**Usage Example:**
```dart
import '../utils/navigation_helper.dart';

// Navigate to a screen
NavigationHelper.navigateToScreen(context, MyScreen());

// Show modal sheet
NavigationHelper.showModalSheet(context, MyModalContent());

// Safe pop
NavigationHelper.safePop(context);
```

### `navigation_helper_examples.dart`
Documentation file with usage examples for the NavigationHelper class.

## When to Use

- **NavigationHelper**: Use when you need to navigate outside of the main BottomNavigationBar flow
- **Modal sheets**: For quick actions, settings, or temporary content
- **Emergency fallback**: When the main navigation system encounters issues

## Integration with Main Navigation

The main app uses `MainNavigationScreen` with BottomNavigationBar for primary navigation. Use NavigationHelper for:
- One-off screens (settings, about, onboarding)
- Modal dialogs and sheets
- Emergency navigation scenarios
