import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

class PeripheralPage extends StatefulWidget {
  final Peripheral peripheral;
  const PeripheralPage({super.key, required this.peripheral});

  @override
  State<PeripheralPage> createState() => _PeripheralPageState();
}

class _PeripheralPageState extends State<PeripheralPage> {
  final CentralManager _manager = CentralManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _connected = false;

  bool _isRunning = false;
  int _cycleCount = 0;
  int _frequencyMs = 1000; // frecuencia inicial en ms
  Timer? _cycleTimer;

  double _speed = 5.0; // velocidad inicial (0.5 a 10)

  // UUIDs
  final UUID serviceUUID = UUID.fromString(
    "a8193979-b221-4813-b81c-f6756ab38f0e",
  );
  final UUID writeCharUUID = UUID.fromString(
    "a8193979-b221-4813-b81c-f6756ab38f0f",
  );

  GATTCharacteristic? _writeChar;

  // Valores UI
  final TextEditingController _intensityColorController =
      TextEditingController();
  final TextEditingController _durationVibrationController =
      TextEditingController();
  final TextEditingController _delayController = TextEditingController(
    text: "100",
  );

  String? _selectedColor;
  String? _selectedSide;
  final Map<String, Color> _colors = {
    "Rojo": Colors.red,
    "Verde": Colors.green,
    "Azul": Colors.blue,
    "Amarillo": Colors.yellow,
    "Cyan": Colors.cyan,
  };

  @override
  void initState() {
    super.initState();
    _connect();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _setupAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint(" _setupAudioPlayer: $state");
    });
  }

  Future<void> _playSound() async {
    try {
      // Configurar el balance estéreo según el lado seleccionado
      final balance = _selectedSide == "right"
          ? 1.0
          : _selectedSide == "left"
          ? -1.0
          : 0.0;

      await _audioPlayer.setBalance(balance);

      // Reproducir el sonido desde assets
      await _audioPlayer.play(AssetSource('audio.mp3'), volume: 1.0);

      debugPrint("🔊 Reproduciendo sonido en canal: $_selectedSide");
    } catch (e) {
      debugPrint("❌ Error reproduciendo sonido: $e");
    }
  }

  Future<void> _connect() async {
    try {
      await _manager.connect(widget.peripheral);

      final services = await _manager.discoverGATT(widget.peripheral);

      final service = services.firstWhere(
        (s) => s.uuid == serviceUUID,
        orElse: () => throw Exception("Servicio no encontrado"),
      );

      _writeChar = service.characteristics.firstWhere(
        (c) => c.uuid == writeCharUUID,
        orElse: () => throw Exception("Característica no encontrada"),
      );

      setState(() => _connected = true);
      debugPrint("✅ Conectado al dispositivo: ${widget.peripheral.uuid}");
    } catch (e) {
      debugPrint("❌ Error al conectar: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al conectar: $e")));
    }
  }

  Future<void> _disconnect() async {
    await _manager.disconnect(widget.peripheral);
    setState(() => _connected = false);
    debugPrint("🔌 Desconectado del dispositivo: ${widget.peripheral.uuid}");
    Navigator.pop(context);
  }

  Future<void> _sendToBLE() async {
    final int? intensity = int.tryParse(_intensityColorController.text);
    final int? duration = int.tryParse(_durationVibrationController.text);
    final int? colorIndex = _selectedColor != null
        ? _colors.keys.toList().indexOf(_selectedColor!) + 1
        : null;
    final int? delayMs = int.tryParse(_delayController.text);

    if (intensity == null ||
        duration == null ||
        colorIndex == null ||
        _selectedSide == null ||
        delayMs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    try {
      // 1️⃣ Iniciar audio
      debugPrint("🎵 Reproduciendo sonido...");
      await _playSound();

      // 2️⃣ Esperar el retraso configurado
      debugPrint("⏱ Esperando $delayMs ms antes de enviar BLE...");
      await Future.delayed(Duration(milliseconds: delayMs));

      // 3️⃣ Preparar y enviar datos BLE
      final Map<String, dynamic> data = {
        "Dr": _selectedSide,
        "in": intensity,
        "col": colorIndex,
        "Dur": duration,
      };

      final jsonStr = json.encode(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      debugPrint("✅ Enviando datos al BLE: $jsonStr");

      await _manager.writeCharacteristic(
        widget.peripheral,
        _writeChar!,
        value: bytes,
        type: GATTCharacteristicWriteType.withResponse,
      );

      debugPrint("✅ Comando BLE enviado correctamente");
    } catch (e) {
      debugPrint("❌ Error en el proceso: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _toggleFrequency() {
    if (int.tryParse(_intensityColorController.text) == null ||
        int.tryParse(_durationVibrationController.text) == null ||
        _selectedSide == null ||
        int.tryParse(_delayController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Complete todos los campos de configuracion y pruebe manualmente de ser necesario",
          ),
        ),
      );
      return;
    }

    if (_isRunning) {
      // Detener
      _cycleTimer?.cancel();
      setState(() => _isRunning = false);
    } else {
      // Iniciar
      setState(() {
        _isRunning = true;
        _cycleCount = 0;
      });

      _cycleTimer = Timer.periodic(Duration(milliseconds: _frequencyMs), (
        timer,
      ) async {
        // Alternar lado automáticamente
        setState(() {
          _selectedSide = (_selectedSide == "left") ? "right" : "left";
          _cycleCount++;
        });

        // Llamar al flujo de audio+BLE
        await _sendToBLE();
      });
    }
  }

  void _updateFrequencyFromSpeed(double speed) {
    setState(() {
      _speed = speed; // mantener la velocidad visual (0.5 a 10)

      // Convertir la velocidad visual (0.5-10) a velocidad efectiva (0.5-9)
      double effectiveSpeed = 0.5 + ((speed - 0.5) * (9 - 0.5)) / (10 - 0.5);

      // Mapear velocidad efectiva (0.5-9) a tiempo (2000ms-659ms)
      // Usamos una función exponencial para una progresión más suave
      final minTime = 659.0; // tiempo mínimo (velocidad 9)
      final maxTime = 2000.0; // tiempo máximo (velocidad 0.5)

      // Factor de exponenciación (ajustable para cambiar la curva)
      const exponent = 1.5;

      // Calcular el tiempo normalizado (0 a 1)
      double normalizedSpeed = (effectiveSpeed - 0.5) / (9 - 0.5);

      // Aplicar curva exponencial
      double curvedSpeed = pow(normalizedSpeed, exponent).toDouble();

      // Calcular el tiempo resultante
      _frequencyMs = (maxTime - curvedSpeed * (maxTime - minTime)).round();

      // Reiniciar timer si está corriendo
      if (_isRunning) {
        _cycleTimer?.cancel();
        _cycleTimer = Timer.periodic(Duration(milliseconds: _frequencyMs), (
          timer,
        ) async {
          setState(() {
            _selectedSide = (_selectedSide == "left") ? "right" : "left";
            _cycleCount++;
          });
          await _sendToBLE();
        });
      }
    });
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila de tiempo y duración vibración en 2 columnas
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _intensityColorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Intensidad de color",
                    border: OutlineInputBorder(),
                    helperText: "Ingrese la intensidad (max. 255)",
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _durationVibrationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Duración vibración (ms)",
                    border: OutlineInputBorder(),
                    helperText: "Ingrese duración vibración",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Selector de color
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Seleccione un color",
                    helperText: "Ingrese un color",
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedColor,
                  items: _colors.keys
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedColor = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Delay sincronización
              Expanded(
                child: TextField(
                  controller: _delayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Retraso audio → BLE (ms)",
                    border: OutlineInputBorder(),
                    helperText: "Ingrese el retraso en milisegundos",
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Selección Derecho / Izquierdo en fila
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedSide = "left");
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(130, 55),
                  backgroundColor: _selectedSide == "left"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text(
                  "Izquierdo",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedSide = "right");
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(130, 55),
                  backgroundColor: _selectedSide == "right"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text(
                  "Derecho",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Botón central enviar
          ElevatedButton.icon(
            onPressed: _sendToBLE,
            icon: const Icon(Icons.send),
            label: const Text("Enviar comando"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 30),
          const Divider(thickness: 2),
          const SizedBox(height: 20),

          // 🔹 Velocidad con Slider
          Text(
            "Velocidad: ${_speed.toStringAsFixed(1)}x",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _speed,
            min: 0.5,
            max: 10,
            divisions: 19, // pasos de 0.5
            label: "${_speed.toStringAsFixed(1)}x",
            onChanged: (val) => _updateFrequencyFromSpeed(val),
          ),
          Text(
            "Tiempo por lado: $_frequencyMs ms",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _toggleFrequency,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              backgroundColor: _isRunning ? Colors.red : Colors.green,
            ),
            child: Text(
              _isRunning ? "Detener frecuencia" : "Iniciar frecuencia",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Mostrar ciclos realizados
          Text(
            "Ciclos completados: $_cycleCount",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Demo BLE"),
        actions: [
          if (_connected)
            IconButton(icon: const Icon(Icons.close), onPressed: _disconnect),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _connected
            ? _buildForm()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
