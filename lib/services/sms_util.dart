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

/// Opens a WhatsApp chat with one contact, pre-filled with a message —
/// same one-tap-to-send model as SMS. WhatsApp's deep link only supports a
/// single recipient at a time (unlike SMS), so this is called once per
/// contact rather than batched.
Future<bool> openWhatsAppComposer(String number, String message) async {
  final digits = number.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return false;
  final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
