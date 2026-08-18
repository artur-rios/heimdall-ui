import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders [data] as a scannable QR code.
///
/// FR-AU-18 asks for the `otpAuthUri` as a scannable code. The encoding is
/// `qr`'s; the drawing is here, which keeps the dependency to a pure-Dart
/// encoder with no platform code of its own.
///
/// Nothing here throws: AF-09e requires that a code which will not render
/// never blocks setup, so data that cannot be encoded renders nothing and the
/// caller shows the secret as text either way.
class QrCodeView extends StatelessWidget {
  const QrCodeView({required this.data, this.size = 200, super.key});

  final String data;
  final double size;

  /// The encoded matrix, or `null` when this data cannot be encoded.
  ///
  /// The `qr` package throws on input it cannot fit into a symbol; a caller
  /// that must not break over it needs an answer rather than an exception.
  static QrImage? _encode(String data) {
    if (data.isEmpty) {
      return null;
    }

    try {
      return QrImage(
        QrCode(
          payload: QrPayload.fromString(data),
          errorCorrectLevel: QrErrorCorrectLevel.medium,
        ),
      );
    } on Object {
      // Whatever went wrong, the answer is the same: there is no code to show.
      return null;
    }
  }

  /// Whether [data] can be rendered at all, which is what lets a caller decide
  /// between showing the code and saying it is unavailable.
  static bool canRender(String data) => _encode(data) != null;

  @override
  Widget build(BuildContext context) {
    final image = _encode(data);

    if (image == null) {
      return const SizedBox.shrink();
    }

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _QrPainter(
          image: image,
          // The modules are painted in plain black on white rather than in the
          // theme's colours: a scanner reads contrast, and a dark-theme code
          // in low-contrast surface colours is a code that will not scan.
          foreground: Colors.black,
          background: Colors.white,
        ),
      ),
    );
  }
}

/// Paints one QR matrix, module by module.
class _QrPainter extends CustomPainter {
  const _QrPainter({
    required this.image,
    required this.foreground,
    required this.background,
  });

  final QrImage image;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = background,
    );

    // A quiet zone of four modules is part of the specification, not decoration
    // — a code drawn edge to edge is one many scanners will not find.
    const quiet = 4;
    final module = size.width / (modules + quiet * 2);
    final paint = Paint()..color = foreground;

    for (var row = 0; row < modules; row++) {
      for (var column = 0; column < modules; column++) {
        if (!image.isDark(row, column)) {
          continue;
        }

        canvas.drawRect(
          Rect.fromLTWH(
            (column + quiet) * module,
            (row + quiet) * module,
            // A hair of overlap, so neighbouring dark modules do not show a
            // seam of background between them at fractional sizes.
            module + 0.5,
            module + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.foreground != foreground ||
      oldDelegate.background != background;
}
