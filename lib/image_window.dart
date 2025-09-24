import 'dart:async';
import 'dart:io';

import 'package:blotter_avg/dashboard_window.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class ImageWindow extends StatefulWidget {
  static void Function()? openImageFile;
  static FocusNode? focusNode;

  @override
  State<ImageWindow> createState() => _ImageWindowState();
}

class _ImageWindowState extends State<ImageWindow> {
  Offset? _mouseImagePosition;
  Uint8List? imageBytes;
  img.Image? decodedImage;
  Offset? rectStartPx;
  Offset? rectEndPx;
  String? error;
  int? draggingPivotIdx;
  late FocusNode _focusNode;
  final double moveStep = 1;

  final Set<LogicalKeyboardKey> _arrowKeysHeld = {};
  Timer? _moveTimer;
  late VoidCallback _handleFocusChange;

  // Display info
  double _displayImageW = 1;
  double _displayImageH = 1;
  late Rect _imageRect;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _handleFocusChange = () {
      if (!_focusNode.hasFocus) {
        _arrowKeysHeld.clear();
        _moveTimer?.cancel();
      }
    };
    _focusNode.addListener(_handleFocusChange);
    ImageWindow.focusNode = _focusNode;
    ImageWindow.openImageFile = openFile;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (ImageWindow.openImageFile == openFile) {
      ImageWindow.openImageFile = null;
    }
    if (ImageWindow.focusNode == _focusNode) {
      ImageWindow.focusNode = null;
    }
    _focusNode.dispose();
    _moveTimer?.cancel();
    super.dispose();
  }

  Future<void> openFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tif', 'tiff', 'png', 'jpg'],
    );
    if (result != null && result.files.single.path != null) {
      await loadImage(File(result.files.single.path!));
      _focusNode.requestFocus();
    }
  }

  Future<void> loadImage(File file) async {
    try {
      final raw = await file.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        setState(() {
          error = "Format not supported or decoding failed!";
        });
        return;
      }
      final pngBytes = Uint8List.fromList(img.encodePng(decoded));
      setState(() {
        imageBytes = pngBytes;
        decodedImage = decoded;
        error = null;
        rectStartPx = null;
        rectEndPx = null;
        draggingPivotIdx = null;
      });
      _focusNode.requestFocus();
    } catch (e) {
      setState(() {
        error = "Error: $e";
      });
    }
  }

  /// Update the mapping rectangle for displaying the image
  void _updateDisplayRect(BoxConstraints constraints) {
    if (decodedImage == null) {
      _imageRect = const Rect.fromLTWH(0, 0, 1, 1);
      _displayImageW = 1;
      _displayImageH = 1;
      return;
    }
    final imgW = decodedImage!.width.toDouble();
    final imgH = decodedImage!.height.toDouble();
    final widgetW = constraints.maxWidth;
    final widgetH = constraints.maxHeight;

    final imgAspect = imgW / imgH;
    final widgetAspect = widgetW / widgetH;

    if (imgAspect > widgetAspect) {
      _displayImageW = widgetW;
      _displayImageH = widgetW / imgAspect;
    } else {
      _displayImageH = widgetH;
      _displayImageW = widgetH * imgAspect;
    }
    final left = (widgetW - _displayImageW) / 2;
    final top = (widgetH - _displayImageH) / 2;
    _imageRect = Rect.fromLTWH(left, top, _displayImageW, _displayImageH);
  }

  // Convert from widget space to image true-pixel coordinates (may be out of bounds, check as necessary)
  Offset? _widgetToImagePixel(Offset local) {
    if (decodedImage == null) return null;
    final lx = local.dx - _imageRect.left;
    final ly = local.dy - _imageRect.top;
    if (lx < 0 || ly < 0 || lx > _displayImageW || ly > _displayImageH) {
      return null;
    }
    double px = lx * (decodedImage!.width / _displayImageW);
    double py = ly * (decodedImage!.height / _displayImageH);
    return Offset(px, py);
  }

  // Convert image pixel coordinates to widget coordinates
  Offset _imagePixelToWidget(Offset px) {
    double widgetX =
        _imageRect.left + px.dx * (_displayImageW / decodedImage!.width);
    double widgetY =
        _imageRect.top + px.dy * (_displayImageH / decodedImage!.height);
    return Offset(widgetX, widgetY);
  }

  List<Offset> getRectPivots() {
    if (rectStartPx == null || rectEndPx == null) return [];
    final r = Rect.fromPoints(rectStartPx!, rectEndPx!);
    return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  }

  Widget buildDragHandle(Offset pxPos, int idx) {
    const double size = 16;
    Offset shownPos = _imagePixelToWidget(pxPos);
    return Positioned(
      left: shownPos.dx - size / 2,
      top: shownPos.dy - size / 2,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            draggingPivotIdx = idx;
          });
        },
        onPanUpdate: (details) {
          // Move corresponding pivot in pixel space
          Offset? curWidget = _imagePixelToWidget(pxPos) + details.delta;
          Offset? newPx = _widgetToImagePixel(curWidget);
          if (newPx == null) return;
          switch (idx) {
            case 0: // Top-left
              setState(() {
                rectStartPx = newPx;
              });
              break;
            case 1: // Top-right
              setState(() {
                rectStartPx = Offset(rectStartPx!.dx, newPx.dy); // y from new
                rectEndPx = Offset(newPx.dx, rectEndPx!.dy); // x from new
              });
              break;
            case 2: // Bottom-right
              setState(() {
                rectEndPx = newPx;
              });
              break;
            case 3: // Bottom-left
              setState(() {
                rectStartPx = Offset(newPx.dx, rectStartPx!.dy);
                rectEndPx = Offset(rectEndPx!.dx, newPx.dy);
              });
              break;
          }
        },
        onPanEnd: (_) {
          setState(() {
            draggingPivotIdx = null;
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.red, width: 2),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  void _moveRectangleByHeldKeys() {
    if (rectStartPx == null || rectEndPx == null) return;
    double dx = 0, dy = 0;
    if (_arrowKeysHeld.contains(LogicalKeyboardKey.arrowLeft)) dx -= moveStep;
    if (_arrowKeysHeld.contains(LogicalKeyboardKey.arrowRight)) dx += moveStep;
    if (_arrowKeysHeld.contains(LogicalKeyboardKey.arrowUp)) dy -= moveStep;
    if (_arrowKeysHeld.contains(LogicalKeyboardKey.arrowDown)) dy += moveStep;
    if (dx != 0 || dy != 0) {
      setState(() {
        rectStartPx = rectStartPx! + Offset(dx, dy);
        rectEndPx = rectEndPx! + Offset(dx, dy);
      });
    }
  }

  void _maybeStartTimer() {
    if (_moveTimer != null && _moveTimer!.isActive) return;
    _moveTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      _moveRectangleByHeldKeys();
    });
  }

  void _onKey(KeyEvent event) {
    debugPrint("Key event: ${event.logicalKey}");
    if (rectStartPx == null || rectEndPx == null) return;

    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyP) {
        debugPrint("P pressed, computing mean");
        final mean = computeMeanOfRect();
        if (mean != null) {
          DashboardWindow.appendText?.call(mean.toStringAsFixed(2));
        }
        return;
      }
      if (!(key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown)) {
        return;
      }

      bool wasEmpty = _arrowKeysHeld.isEmpty;
      _arrowKeysHeld.add(key);
      if (wasEmpty && _arrowKeysHeld.isNotEmpty) {
        _maybeStartTimer();
      }
      _moveRectangleByHeldKeys();
    }
    if (event is KeyUpEvent) {
      _arrowKeysHeld.remove(key);
      if (_arrowKeysHeld.isEmpty) {
        _moveTimer?.cancel();
      }
    }
  }

  double? computeMeanOfRect() {
    if (rectStartPx == null || rectEndPx == null || decodedImage == null) {
      return null;
    }
    final img.Image image = decodedImage!;

    int x0 = rectStartPx!.dx.round().clamp(0, image.width - 1);
    int y0 = rectStartPx!.dy.round().clamp(0, image.height - 1);
    int x1 = rectEndPx!.dx.round().clamp(0, image.width - 1);
    int y1 = rectEndPx!.dy.round().clamp(0, image.height - 1);

    int left = x0 < x1 ? x0 : x1;
    int top = y0 < y1 ? y0 : y1;
    int right = x0 > x1 ? x0 : x1;
    int bottom = y0 > y1 ? y0 : y1;

    int sum = 0, count = 0;
    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        final pixel = image.getPixel(x, y);
        int grey = (pixel.r).toInt();
        sum += grey;
        count++;
      }
    }
    if (count == 0) return null;
    return sum / count;
  }

  Widget _buildInfoBoard() {
    String mouseInfo = '';
    if (_mouseImagePosition != null) {
      mouseInfo =
          'Mouse: (${_mouseImagePosition!.dx.toStringAsFixed(1)}, ${_mouseImagePosition!.dy.toStringAsFixed(1)})';
    } else {
      mouseInfo = 'Mouse: (not over image)';
    }
    String rectInfo = '';
    if (rectStartPx != null && rectEndPx != null) {
      rectInfo =
          'Rect(px): (${rectStartPx!.dx.round()}, ${rectStartPx!.dy.round()}) → (${rectEndPx!.dx.round()}, ${rectEndPx!.dy.round()})';
    } else {
      rectInfo = 'Rect: (not drawn)';
    }

    String meanInfo = '';
    double? mean = computeMeanOfRect();
    if (mean != null) {
      meanInfo = 'Mean: ${mean.toStringAsFixed(2)}';
    } else {
      meanInfo = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      width: double.infinity,
      color: Colors.black.withOpacity(0.8),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(mouseInfo), Text(rectInfo), Text(meanInfo)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) async {
        for (final file in details.files) {
          final path = file.path.toLowerCase();
          if (path.endsWith('.tif') ||
              path.endsWith('.tiff') ||
              path.endsWith('.png') ||
              path.endsWith('.jpg')) {
            await loadImage(File(file.path));
            break;
          }
        }
      },
      child: Center(
        child: error != null
            ? Text(error!, style: const TextStyle(color: Colors.red))
            : imageBytes == null
            ? const Text('Drag & drop TIFF/PNG/JPG, or click open in Dashboard')
            : LayoutBuilder(
                builder: (context, constraints) {
                  _updateDisplayRect(constraints);
                  return Focus(
                    autofocus: true,
                    focusNode: _focusNode,
                    onKeyEvent: (FocusNode node, KeyEvent event) {
                      if ([
                        LogicalKeyboardKey.arrowLeft,
                        LogicalKeyboardKey.arrowRight,
                        LogicalKeyboardKey.arrowUp,
                        LogicalKeyboardKey.arrowDown,
                        LogicalKeyboardKey.keyP,
                      ].contains(event.logicalKey)) {
                        _onKey(event);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _focusNode.requestFocus();
                      },
                      onPanStart: (details) {
                        if (draggingPivotIdx == null && decodedImage != null) {
                          final imgPx = _widgetToImagePixel(
                            details.localPosition,
                          );
                          if (imgPx != null) {
                            setState(() {
                              rectStartPx = imgPx;
                              rectEndPx = null;
                            });
                          }
                        }
                      },
                      onPanUpdate: (details) {
                        if (draggingPivotIdx == null && decodedImage != null) {
                          final imgPx = _widgetToImagePixel(
                            details.localPosition,
                          );
                          if (imgPx != null) {
                            setState(() {
                              rectEndPx = imgPx;
                            });
                          }
                        }
                      },
                      onPanEnd: (details) {
                        if (draggingPivotIdx == null &&
                            rectStartPx != null &&
                            rectEndPx != null) {
                          setState(() {});
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: MouseRegion(
                              onHover: (event) {
                                final imgPt = _widgetToImagePixel(
                                  event.localPosition,
                                );
                                setState(() {
                                  _mouseImagePosition = imgPt;
                                });
                              },
                              onExit: (event) {
                                setState(() => _mouseImagePosition = null);
                              },
                              child: Stack(
                                children: [
                                  Positioned.fromRect(
                                    rect: _imageRect,
                                    child: Image.memory(
                                      imageBytes!,
                                      width: _displayImageW,
                                      height: _displayImageH,
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  if (rectStartPx != null && rectEndPx != null)
                                    Positioned.fromRect(
                                      rect: _imageRect,
                                      child: CustomPaint(
                                        size: Size(
                                          _displayImageW,
                                          _displayImageH,
                                        ),
                                        painter: RectPainterImagePx(
                                          rectStartPx!,
                                          rectEndPx!,
                                          decodedImage!.width,
                                          decodedImage!.height,
                                        ),
                                      ),
                                    ),
                                  if (rectStartPx != null && rectEndPx != null)
                                    ...getRectPivots()
                                        .asMap()
                                        .entries
                                        .map(
                                          (e) =>
                                              buildDragHandle(e.value, e.key),
                                        )
                                        .toList(),
                                ],
                              ),
                            ),
                          ),
                          _buildInfoBoard(),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Custom Painter that takes image pixel coordinates and maps them to display-coords
class RectPainterImagePx extends CustomPainter {
  final Offset startPx;
  final Offset endPx;
  final int imageW;
  final int imageH;

  RectPainterImagePx(this.startPx, this.endPx, this.imageW, this.imageH);

  @override
  void paint(Canvas canvas, Size size) {
    Offset mapPxToDisplay(Offset px) =>
        Offset(px.dx * (size.width / imageW), px.dy * (size.height / imageH));
    final rect = Rect.fromPoints(
      mapPxToDisplay(startPx),
      mapPxToDisplay(endPx),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant RectPainterImagePx oldDelegate) =>
      oldDelegate.startPx != startPx ||
      oldDelegate.endPx != endPx ||
      oldDelegate.imageW != imageW ||
      oldDelegate.imageH != imageH;
}
