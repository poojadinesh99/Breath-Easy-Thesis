import 'package:flutter/material.dart';

/// Navigation utility class for safe screen navigation
/// Provides fallback navigation methods when BottomNavigationBar is not suitable
class NavigationHelper {
  
  /// Safely navigate to a screen with error handling
  /// Useful for modal navigation or when navigating from outside the main navigation
  static Future<void> navigateToScreen(
    BuildContext context, 
    Widget screen, {
    bool fullScreenDialog = false,
    String? routeName,
  }) async {
    if (!context.mounted) return;
    
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => screen,
          fullscreenDialog: fullScreenDialog,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    }
  }

  /// Navigate and replace the current screen
  static Future<void> navigateAndReplace(
    BuildContext context, 
    Widget screen, {
    String? routeName,
  }) async {
    if (!context.mounted) return;
    
    try {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => screen,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show a modal bottom sheet with safe error handling
  static Future<T?> showModalSheet<T>(
    BuildContext context,
    Widget child, {
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) async {
    if (!context.mounted) return null;
    
    try {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => child,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing modal: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }

  /// Safe pop with optional result
  static void safePop<T>(BuildContext context, [T? result]) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  /// Pop until a specific route
  static void popUntil(BuildContext context, String routeName) {
    if (context.mounted) {
      Navigator.of(context).popUntil(ModalRoute.withName(routeName));
    }
  }
}
