import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Chrome: saves a file to the Downloads folder.
void downloadBytes(Uint8List bytes, String name, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// Chrome: opens the default mail app with a prefilled subject.
void openMailto(String subject, String body) {
  web.window.open(
      'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}', '_self');
}

/// Chrome: asks the user to allow browser notifications.
void requestWebNotifyPermission() {
  try {
    if (web.Notification.permission != 'granted') {
      web.Notification.requestPermission();
    }
  } catch (_) {}
}

/// Chrome: shows a real desktop notification (if allowed).
void webNotify(String title, String body) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(title, web.NotificationOptions(body: body));
    }
  } catch (_) {}
}

/// Chrome: plays a beep pattern with the Web Audio API (no sound file needed).
/// default = 2 soft beeps, alarm = 6 loud beeps, ringtone = 3-note melody.
void playWebSound(String sound) {
  try {
    final ctx = web.AudioContext();
    final t0 = ctx.currentTime + 0.05;
    List<List<double>> notes; // [frequency, start, duration]
    String wave = 'sine';
    switch (sound) {
      case 'alarm':
        wave = 'square';
        notes = [for (var i = 0; i < 6; i++) [1000.0, i * 0.3, 0.2]];
        break;
      case 'ringtone':
        notes = [
          [523.0, 0.0, 0.25],
          [659.0, 0.3, 0.25],
          [784.0, 0.6, 0.5],
          [523.0, 1.2, 0.25],
          [659.0, 1.5, 0.25],
          [784.0, 1.8, 0.5],
        ];
        break;
      default:
        notes = [
          [880.0, 0.0, 0.2],
          [880.0, 0.35, 0.2],
        ];
    }
    for (final n in notes) {
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.type = wave;
      osc.frequency.value = n[0];
      gain.gain.value = wave == 'square' ? 0.15 : 0.3;
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t0 + n[1]);
      osc.stop(t0 + n[1] + n[2]);
    }
  } catch (_) {}
}
