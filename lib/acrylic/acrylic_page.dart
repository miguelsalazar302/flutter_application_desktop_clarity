import 'package:application_desktop_ble/acrylic/transparent_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window.dart';
import 'package:flutter_acrylic/window_effect.dart';

class AcrylicPage extends StatefulWidget {
  const AcrylicPage({super.key});
  @override
  State<AcrylicPage> createState() => _AcrylicPageState();
}

class _AcrylicPageState extends State<AcrylicPage> {
  int _counter = 0;
  WindowEffect effect = WindowEffect.solid;
  Color color = Colors.white;

  @override
  void initState() {
    setWindowEffect(effect, color);
    super.initState();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void setWindowEffect(WindowEffect effect, Color color) {
    if (effect == WindowEffect.transparent) {
      Window.setWindowBackgroundColorToClear();
      Window.addEmptyMaskImage();
      Window.disableShadow();
    } else {
      Window.setWindowBackgroundColorToDefaultColor();
      Window.removeMaskImage();
      Window.enableShadow();
    }

    Window.setEffect(effect: effect, color: color);
    setState(() {
      this.effect = effect;
      this.color = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: effect == WindowEffect.transparent
          ? Colors.transparent
          : Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Flutter Demo Home Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
              style: TextStyle(
                color: effect == WindowEffect.transparent ? Colors.white : null,
              ),
            ),
            Text(
              '$_counter',
              style: TextStyle(
                color: effect == WindowEffect.transparent ? Colors.white : null,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () =>
                      setWindowEffect(WindowEffect.solid, Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effect == WindowEffect.solid
                        ? Colors.blue[200]
                        : null,
                  ),
                  child: Text('Solid'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => setWindowEffect(
                    WindowEffect.transparent,
                    Colors.transparent,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effect == WindowEffect.transparent
                        ? Colors.blue[200]
                        : null,
                  ),
                  child: Text('Transparent'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () async {
                    // Ir a pantalla de conexión
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TransparentPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effect == WindowEffect.transparent
                        ? Colors.blue[200]
                        : null,
                  ),
                  child: Text('Go Transparent'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
