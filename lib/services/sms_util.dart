import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's native SMS composer pre-filled with a message and
/// recipients. Requires one tap from the user to actually send — neither
/// Android nor iOS allow apps to send SMS silently without that sensitive
/// permission, so this is the free, no-special-permission way to reach
/// someone who isn't a SafeScan user.
Future<bool> openSmsComposer(List<String> numbers, String message) async {
  if (numbers.isEmpty) return false;
  final separator = Platform.isIOS ? '&' : '?';
  final uri = Uri.parse('sms:${numbers.join(',')}$separator' 'body=${Uri.encodeComponent(message)}');
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  return false;
}
