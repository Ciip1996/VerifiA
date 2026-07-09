import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Renders [qrData] to a white-padded PNG and opens the OS share sheet with the
/// image attached plus optional [text]. Used for the "scan me" in-person handoff
/// (e.g. a verification receipt QR) — the same QR-to-PNG pattern as the create
/// challenge screen, factored out so multiple screens can reuse it.
///
/// Returns true if the share sheet was presented, false on failure.
Future<bool> shareQrPng(
  BuildContext context, {
  required String qrData,
  String? text,
  Rect? sharePositionOrigin,
  String fileName = 'verifia_receipt_qr.png',
}) async {
  File? tmpFile;
  try {
    const size = 900.0;
    const padding = 48.0;
    const qrSize = size - padding * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.white,
    );

    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    canvas.save();
    canvas.translate(padding, padding);
    qrPainter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return false;

    tmpFile = File(
      '${Directory.systemTemp.path}/verifia_qr_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tmpFile.writeAsBytes(byteData.buffer.asUint8List());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tmpFile.path, mimeType: 'image/png', name: fileName)],
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return true;
  } catch (_) {
    return false;
  } finally {
    tmpFile?.deleteSync();
  }
}
