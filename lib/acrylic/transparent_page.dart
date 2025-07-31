import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window.dart';
import 'package:flutter_acrylic/window_effect.dart';

class TransparentPage extends StatefulWidget {
  const TransparentPage({super.key});

  @override
  State<TransparentPage> createState() => _TransparentPageState();
}

enum MovementMode { none, vertical, diagonal1, diagonal2, horizontal, infinity }

MovementMode _mode = MovementMode.none;

class _TransparentPageState extends State<TransparentPage>
    with SingleTickerProviderStateMixin {
  WindowEffect effect = WindowEffect.solid;
  Color color = Colors.white;

  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _menuOpen = false;

  // Base y límites
  final double baseDuration = 3.0; // Duración base en segundos
  final double step = 0.5; // Paso para cambiar velocidad
  final int maxSteps = 5; // Máximo pasos para subir o bajar

  double _speedSeconds = 2.0; // Duración actual

  // Para control de límites:
  double get minSpeed => baseDuration - maxSteps * step; // Ej: 2 - 1 = 1.0 seg
  double get maxSpeed => baseDuration + maxSteps * step; // Ej: 2 + 1 = 3.0 seg

  @override
  void initState() {
    super.initState();
    setWindowEffect(effect, color);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_speedSeconds * 1000).toInt()),
    );

    _animation =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        )..addListener(() {
          setState(() {});
        });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
  }

  void _toggleMenu() {
    setState(() {
      _menuOpen = !_menuOpen;
    });
  }

  void _selectOption(Function action) {
    setState(() {
      _menuOpen = false; // ocultar menú al seleccionar
    });
    action(); // ejecutar acción
  }

  void setWindowEffect(WindowEffect effect, Color color) async {
    if (effect == WindowEffect.transparent) {
      Window.setWindowBackgroundColorToClear();
      Window.makeTitlebarTransparent();
      Window.addEmptyMaskImage();
      Window.disableShadow();
    } else {
      Window.setWindowBackgroundColorToDefaultColor();
      Window.makeTitlebarOpaque();
      Window.removeMaskImage();
      Window.enableShadow();
    }

    Window.setEffect(effect: effect, color: color);
    setState(() {
      this.effect = effect;
      this.color = color;
    });
  }

  void setSpeed(double seconds) {
    seconds = seconds.clamp(minSpeed, maxSpeed);
    final progress = _controller.value;
    final oldDuration = _controller.duration!.inMilliseconds;
    final newDuration = (seconds * 1000).toInt();
    final remainingTime = (1.0 - progress) * oldDuration;
    _speedSeconds = seconds;
    _controller.duration = Duration(milliseconds: newDuration);
    final newProgress = 1.0 - (remainingTime / newDuration);

    if (_controller.status == AnimationStatus.reverse) {
      _controller.reverse(from: newProgress.clamp(0.0, 1.0));
    } else if (_controller.status == AnimationStatus.forward) {
      _controller.forward(from: newProgress.clamp(0.0, 1.0));
    } else {
      _controller.forward(from: newProgress.clamp(0.0, 1.0));
    }
  }

  void _startVerticalAnimation(BoxConstraints constraints) {
    _controller.stop();
    _speedSeconds = 2.0;
    setSpeed(_speedSeconds);
    _mode = MovementMode.vertical;

    final height = constraints.maxHeight;
    final topY = -height / 2 + 50;
    final bottomY = height / 2 - 50;

    _animation =
        Tween<Offset>(begin: Offset(0, bottomY), end: Offset(0, topY)).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        )..addListener(() {
          setState(() {});
        });

    _controller.reset();
    _controller.forward();
  }

  void _startDiagonal1Animation(BoxConstraints constraints) {
    // Diagonal de esquina inferior izquierda a esquina superior derecha
    _controller.stop();
    _speedSeconds = 2.0;
    setSpeed(_speedSeconds);
    _mode = MovementMode.diagonal1;

    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final bottomLeft = Offset(-width / 2 + 50, height / 2 - 50);
    final topRight = Offset(width / 2 - 50, -height / 2 + 50);

    _animation =
        Tween<Offset>(begin: bottomLeft, end: topRight).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        )..addListener(() {
          setState(() {});
        });

    _controller.reset();
    _controller.forward();
  }

  void _startDiagonal2Animation(BoxConstraints constraints) {
    // Diagonal de esquina superior izquierda a esquina inferior derecha
    _controller.stop();
    _speedSeconds = 2.0;
    setSpeed(_speedSeconds);
    _mode = MovementMode.diagonal2;

    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final topLeft = Offset(-width / 2 + 50, -height / 2 + 50);
    final bottomRight = Offset(width / 2 - 50, height / 2 - 50);

    _animation =
        Tween<Offset>(begin: topLeft, end: bottomRight).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        )..addListener(() {
          setState(() {});
        });

    _controller.reset();
    _controller.forward();
  }

  void _startHorizontalAnimation(BoxConstraints constraints) {
    // Movimiento horizontal centro vertical, izquierda a derecha
    _controller.stop();
    _speedSeconds = 2.0;
    setSpeed(_speedSeconds);
    _mode = MovementMode.horizontal;

    final width = constraints.maxWidth;
    final centerY = 0.0;

    final leftX = -width / 2 + 50;
    final rightX = width / 2 - 50;

    _animation =
        Tween<Offset>(
            begin: Offset(leftX, centerY),
            end: Offset(rightX, centerY),
          ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear))
          ..addListener(() {
            setState(() {});
          });

    _controller.reset();
    _controller.forward();
  }

  void _stopAnimation() {
    _controller.stop();
    _speedSeconds = 2.0;
    setSpeed(_speedSeconds);
    _mode = MovementMode.none;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final offset = _mode == MovementMode.none
            ? Offset.zero
            : _animation.value;

        return Center(
          child: Transform.translate(
            offset: offset,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: effect == WindowEffect.transparent
          ? Colors.transparent
          : Colors.white,
      body: _buildBody(),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Solo mostrar los botones si _menuOpen es true
              if (_menuOpen) ...[
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'vertical',
                  onPressed: () =>
                      _selectOption(() => _startVerticalAnimation(constraints)),
                  tooltip: 'Mover arriba y abajo',
                  child: const Icon(Icons.swap_vert),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'diagonal1',
                  onPressed: () => _selectOption(
                    () => _startDiagonal1Animation(constraints),
                  ),
                  tooltip: 'Diagonal inferior izquierda a superior derecha',
                  child: const Icon(Icons.arrow_upward_outlined),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'diagonal2',
                  onPressed: () => _selectOption(
                    () => _startDiagonal2Animation(constraints),
                  ),
                  tooltip: 'Diagonal superior izquierda a inferior derecha',
                  child: const Icon(Icons.arrow_downward_outlined),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'horizontal',
                  onPressed: () => _selectOption(
                    () => _startHorizontalAnimation(constraints),
                  ),
                  tooltip: 'Mover izquierda a derecha',
                  child: const Icon(Icons.swap_horiz),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'stop',
                  onPressed: () => _selectOption(_stopAnimation),
                  tooltip: 'Detener movimiento',
                  child: const Icon(Icons.stop),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'solidEffect',
                  onPressed: () => _selectOption(
                    () => setWindowEffect(WindowEffect.solid, Colors.white),
                  ),
                  tooltip: 'Solid Effect',
                  child: const Icon(Icons.square),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'transparentEffect',
                  onPressed: () => _selectOption(
                    () => setWindowEffect(
                      WindowEffect.transparent,
                      Colors.transparent,
                    ),
                  ),
                  tooltip: 'Transparent Effect',
                  child: const Icon(Icons.check_box_outline_blank),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'speedUp',
                  onPressed: () => _selectOption(() {
                    if (_speedSeconds > minSpeed) {
                      print('speedUp');
                      setSpeed(_speedSeconds - step);
                    }
                  }),
                  tooltip: 'Aumentar velocidad',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'speedDown',
                  onPressed: () => _selectOption(() {
                    if (_speedSeconds < maxSpeed) {
                      print('speedDown');
                      setSpeed(_speedSeconds + step);
                    }
                  }),
                  tooltip: 'Disminuir velocidad',
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'goBack',
                  onPressed: () => _selectOption(() => Navigator.pop(context)),
                  tooltip: 'Volver',
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(height: 10),
              ],

              // Botón principal que abre o cierra el menú
              FloatingActionButton(
                heroTag: 'menuToggle',
                onPressed: _toggleMenu,
                tooltip: _menuOpen ? 'Cerrar menú' : 'Abrir menú',
                child: Icon(_menuOpen ? Icons.close : Icons.menu),
              ),
            ],
          );
        },
      ),
    );
  }
}
