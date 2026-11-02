import 'package:flutter/material.dart';

/// Keeps the photograph visible while long attribution remains scrollable.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.title,
    required this.image,
    required this.caption,
  });
  final String title;
  final Widget image;
  final String caption;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor, Size size) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 4.0);
    final center = Offset(size.width / 2, size.height / 2);
    final scene = _transform.toScene(center);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * next,
        center.dy - scene.dy * next,
        0,
        1,
      )
      ..scaleByDouble(next, next, 1, 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, imageConstraints) => Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        maxScale: 4,
                        child: SizedBox.expand(child: widget.image),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '축소',
                          onPressed: () => _zoom(
                            1 / 1.5,
                            Size(
                              imageConstraints.maxWidth,
                              imageConstraints.maxHeight - 48,
                            ),
                          ),
                          icon: const Icon(Icons.zoom_out),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '원래 크기',
                          onPressed: () =>
                              _transform.value = Matrix4.identity(),
                          icon: const Icon(Icons.fit_screen),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '확대',
                          onPressed: () => _zoom(
                            1.5,
                            Size(
                              imageConstraints.maxWidth,
                              imageConstraints.maxHeight - 48,
                            ),
                          ),
                          icon: const Icon(Icons.zoom_in),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .35,
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.caption,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
