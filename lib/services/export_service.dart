import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

/// CSV + PDF export. PDF is written by hand (no extra library needed).
class ExportService {
  static String _esc(String s) => '"${s.replaceAll('"', '""')}"';

  static List<List<String>> _rows(List<Task> tasks) {
    final now = DateTime.now();
    return tasks.map((t) {
      final subsDone = t.subtasks.where((s) => s.done).length;
      return [
        t.title,
        t.description,
        t.isRepeating ? fmtTime(t.dueDate) : '${fmtDate(t.dueDate)} ${fmtTime(t.dueDate)}',
        t.repeatLabel,
        t.isDoneOn(now) ? 'Completed' : 'Pending',
        t.subtasks.isEmpty ? '-' : '$subsDone/${t.subtasks.length} (${(t.progress * 100).round()}%)',
      ];
    }).toList();
  }

  static const _headers = ['Title', 'Description', 'Due', 'Repeat', 'Status', 'Progress'];

  static String _csvString(List<Task> tasks) {
    final sb = StringBuffer()..writeln(_headers.join(','));
    for (final r in _rows(tasks)) {
      sb.writeln(r.map(_esc).join(','));
    }
    return sb.toString();
  }

  static Uint8List _csvBytes(List<Task> tasks) =>
      Uint8List.fromList(utf8.encode(_csvString(tasks)));

  static Future<File> exportCsv(List<Task> tasks) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/tasks.csv');
    return f.writeAsString(_csvString(tasks));
  }

  // ---------- minimal PDF writer ----------
  static String _pdfText(String s, [int max = 100]) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r == 0x5C || r == 0x28 || r == 0x29) {
        b.write('\\');
        b.writeCharCode(r);
      } else if (r >= 32 && r < 127) {
        b.writeCharCode(r);
      } else {
        b.write('?');
      }
    }
    final out = b.toString();
    return out.length > max ? '${out.substring(0, max)}...' : out;
  }

  static String _buildPdf(String title, List<String> lines) {
    const perPage = 52;
    final pages = <List<String>>[];
    for (var i = 0; i < lines.length; i += perPage) {
      final end = i + perPage > lines.length ? lines.length : i + perPage;
      pages.add(lines.sublist(i, end));
    }
    if (pages.isEmpty) pages.add([]);
    final n = pages.length;

    final objs = <int, String>{};
    objs[1] = '<< /Type /Catalog /Pages 2 0 R >>';
    final kids = [for (var i = 0; i < n; i++) '${4 + 2 * i} 0 R'].join(' ');
    objs[2] = '<< /Type /Pages /Kids [$kids] /Count $n >>';
    objs[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';
    for (var i = 0; i < n; i++) {
      final c = StringBuffer('BT\n');
      if (i == 0) {
        c.write('/F1 16 Tf 40 805 Td 20 TL (${_pdfText(title)}) Tj T*\n/F1 9 Tf 13 TL\n');
      } else {
        c.write('/F1 9 Tf 40 805 Td 13 TL\n');
      }
      for (final l in pages[i]) {
        c.write('(${_pdfText(l, 105)}) Tj T*\n');
      }
      c.write('ET');
      final content = c.toString();
      objs[4 + 2 * i] =
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + 2 * i} 0 R >>';
      objs[5 + 2 * i] = '<< /Length ${content.length} >>\nstream\n$content\nendstream';
    }

    final maxId = 3 + 2 * n;
    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var id = 1; id <= maxId; id++) {
      offsets.add(out.length);
      out.write('$id 0 obj\n${objs[id]}\nendobj\n');
    }
    final xref = out.length;
    out.write('xref\n0 ${maxId + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    out.write('trailer\n<< /Size ${maxId + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF');
    return out.toString();
  }

  static String _pdfString(List<Task> tasks) {
    final lines = <String>[];
    var i = 1;
    for (final r in _rows(tasks)) {
      lines.add('$i. ${r[0]}  |  ${r[2]}  |  ${r[3]}  |  ${r[4]}  |  ${r[5]}');
      if (r[1].isNotEmpty) lines.add('      ${r[1].replaceAll('\n', ' ')}');
      i++;
    }
    return _buildPdf('My Tasks', lines);
  }

  static Uint8List _pdfBytes(List<Task> tasks) => Uint8List.fromList(_pdfString(tasks).codeUnits);

  static Future<File> exportPdf(List<Task> tasks) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/tasks.pdf');
    return f.writeAsBytes(_pdfBytes(tasks));
  }

  static Future<void> shareCsv(List<Task> tasks) async {
    if (kIsWeb) {
      downloadBytes(_csvBytes(tasks), 'tasks.csv', 'text/csv');
      return;
    }
    final f = await exportCsv(tasks);
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: 'My Tasks (CSV)');
  }

  static Future<void> sharePdf(List<Task> tasks) async {
    if (kIsWeb) {
      downloadBytes(_pdfBytes(tasks), 'tasks.pdf', 'application/pdf');
      return;
    }
    final f = await exportPdf(tasks);
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/pdf')], subject: 'My Tasks (PDF)');
  }

  /// Email: choose Gmail/Outlook in the share sheet; both files attached.
  static Future<void> shareEmail(List<Task> tasks) async {
    if (kIsWeb) {
      // Chrome: download both files, then open the mail app (attach the downloaded files).
      downloadBytes(_csvBytes(tasks), 'tasks.csv', 'text/csv');
      downloadBytes(_pdfBytes(tasks), 'tasks.pdf', 'application/pdf');
      openMailto('My Task List', 'Hi, my task list is attached (tasks.csv and tasks.pdf from Downloads).');
      return;
    }
    final c = await exportCsv(tasks);
    final p = await exportPdf(tasks);
    await Share.shareXFiles(
      [XFile(c.path, mimeType: 'text/csv'), XFile(p.path, mimeType: 'application/pdf')],
      subject: 'My Task List',
      text: 'Hi, my task list is attached (CSV + PDF).',
    );
  }
}
