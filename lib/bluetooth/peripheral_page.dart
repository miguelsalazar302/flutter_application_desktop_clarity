import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart' show rootBundle;

class PeripheralPage extends StatefulWidget {
  final Peripheral peripheral;
  final String name;
  const PeripheralPage({
    super.key,
    required this.peripheral,
    required this.name,
  });

  @override
  State<PeripheralPage> createState() => _PeripheralPageState();
}

class _PeripheralPageState extends State<PeripheralPage> {
  final CentralManager _manager = CentralManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _cachedSounds = {};
  bool _connected = false;

  bool _isRunning = false;
  int _cycleCount = 0;
  Timer? _cycleTimer;

  String _soundType = 'click-1125.mp3'; // sonido inicial
  String _animationType =
      "horizontal"; // horizontal | vertical | diagonal-right | diagonal-left

  // UUIDs
  final UUID serviceUUID = UUID.fromString(
    "a8193979-b221-4813-b81c-f6756ab38f0e",
  );
  final UUID writeCharUUID = UUID.fromString(
    "a8193979-b221-4813-b81c-f6756ab38f0f",
  );

  GATTCharacteristic? _writeChar;

  // Valores UI
  final TextEditingController _intensityColorController = TextEditingController(
    text: "100",
  );
  final TextEditingController _vinController = TextEditingController(
    text: "50",
  );
  final TextEditingController _vspController = TextEditingController(
    text: "50",
  );
  final TextEditingController _delayController = TextEditingController(
    text: "0",
  );

  String? _selectedColor = "Verde";
  String? _selectedSide =
      "right"; // horizontal | vertical | diagonal-right | diagonal-left

  final Map<String, Color> _colors = {
    "Rojo": Colors.red,
    "Verde": Colors.green,
    "Azul": Colors.blue,
    "Amarillo": Colors.yellow,
    "Cyan": Colors.cyan,
  };

  // ordenada de más lento (4s) a más rápido (250 ms)
  final List<int> _timeSteps = [
    4000,
    2500,
    2000,
    1700,
    1500,
    1350,
    1000,
    850,
    750,
    650,
    625,
    600,
    550,
    500,
    450,
    400,
    375,
    350,
    325,
    300,
    275,
    250,
  ];

  double _speedIndex = 6; // por ejemplo apunta a 1000ms inicial
  int get _frequencyMs => _timeSteps[_speedIndex.round()];

  @override
  void initState() {
    super.initState();
    _preloadSounds();
    _connect();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _cycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _preloadSounds() async {
    // Lista de todos los audios posibles
    const files = ['click-1125.mp3', 'tap-2585.mp3', 'select-3124.mp3'];

    for (final f in files) {
      final bytes = await rootBundle.load('assets/$f');
      _cachedSounds[f] = bytes.buffer.asUint8List();
    }

    debugPrint("✅ Audios precargados en memoria");
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

  Future<void> _playSound() async {
    try {
      final balance = _selectedSide == "right"
          ? 1.0
          : _selectedSide == "left"
          ? -1.0
          : 0.0;

      await _audioPlayer.setBalance(balance);

      final bytes = _cachedSounds[_soundType];
      if (bytes == null) {
        debugPrint("⚠️ Audio no precargado, reproduciendo desde assets");
        await _audioPlayer.play(AssetSource(_soundType));
        return;
      }

      // Reproduce desde memoria directamente
      await _audioPlayer.play(BytesSource(bytes));
      debugPrint("🔊 Reproduciendo $_soundType en canal: $_selectedSide");
    } catch (e) {
      debugPrint("❌ Error reproduciendo sonido: $e");
    }
  }

  Future<void> _sendToBLE() async {
    final int? intensity = int.tryParse(_intensityColorController.text);
    final int? vin = int.tryParse(_vinController.text);
    final int? vsp = int.tryParse(_vspController.text);
    final int? colorIndex = _selectedColor != null
        ? _colors.keys.toList().indexOf(_selectedColor!) + 1
        : null;
    final int? delayMs = int.tryParse(_delayController.text);

    if (intensity == null ||
        vin == null ||
        vsp == null ||
        colorIndex == null ||
        _selectedSide == null ||
        delayMs == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Complete all fields")));
      return;
    }

    try {
      // 1️⃣ Iniciar audio
      debugPrint("🎵 Reproduciendo sonido...");
      _playSound();

      // 2️⃣ Esperar el retraso configurado
      if (delayMs > 0) {
        debugPrint("⏱ Esperando $delayMs ms antes de enviar BLE...");
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      // 3️⃣ Preparar y enviar datos BLE
      final Map<String, dynamic> data = {
        "Dr": _selectedSide,
        "In": intensity,
        "Col": colorIndex,
        "Vin": vin,
        "Vsp": vsp,
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
        int.tryParse(_vinController.text) == null ||
        int.tryParse(_vspController.text) == null ||
        _selectedSide == null ||
        int.tryParse(_delayController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Complete all configuration fields and test manually if necessary.",
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
        // 1️⃣ Cambiar lado de destino para que AnimatedAlign comience a moverse
        setState(() {
          _selectedSide = (_selectedSide == "left") ? "right" : "left";
          _cycleCount++;
        });

        // 2️⃣ Esperar exactamente el tiempo que dura la animación
        //    (el mismo _frequencyMs) antes de disparar audio+BLE
        Future.delayed(Duration(milliseconds: _frequencyMs), () async {
          await _sendToBLE(); // 🔊 click cuando ya llegó
        });
      });
    }
  }

  void _updateFrequencyFromSpeed(double val) {
    setState(() {
      _speedIndex = val;
      // Reinicia el timer si está corriendo
      if (_isRunning) {
        _cycleTimer?.cancel();
        _cycleTimer = Timer.periodic(Duration(milliseconds: _frequencyMs), (
          timer,
        ) async {
          // 1️⃣ Cambiar lado de destino para que AnimatedAlign comience a moverse
          setState(() {
            _selectedSide = (_selectedSide == "left") ? "right" : "left";
            _cycleCount++;
          });

          // 2️⃣ Esperar exactamente el tiempo que dura la animación
          //    (el mismo _frequencyMs) antes de disparar audio+BLE
          Future.delayed(Duration(milliseconds: _frequencyMs), () async {
            await _sendToBLE(); // 🔊 click cuando ya llegó
          });
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
                  controller: _vinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Intensity de vibration",
                    border: OutlineInputBorder(),
                    helperText: "Range: 0-100",
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _vspController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Speed de vibration",
                    border: OutlineInputBorder(),
                    helperText: "Range: 0-100",
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
                    labelText: "Select a color",
                    helperText: "Enter a color",
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

              Expanded(
                child: TextField(
                  controller: _intensityColorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Color intensity",
                    border: OutlineInputBorder(),
                    helperText: "Enter the intensity (max. 255)",
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Delay sincronización
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _delayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Audio Delay → BLE (ms)",
                    border: OutlineInputBorder(),
                    helperText: "Enter the delay in milliseconds",
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

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
                  "Left sound",
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
                  "Right sound",
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
            label: const Text("Send command"),
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
            "Speed: ${_speedIndex.toStringAsFixed(1)}x",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _speedIndex,
            min: 0,
            max: (_timeSteps.length - 1).toDouble(),
            divisions: _timeSteps.length - 1,
            label: '$_frequencyMs ms',
            onChanged: (val) => _updateFrequencyFromSpeed(val),
          ),
          Text(
            "Time per side: $_frequencyMs ms",
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
              _isRunning ? "Stop frequency" : "Start frequency",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Mostrar ciclos realizados
          Text(
            "Completed cycles: $_cycleCount",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _soundType = "click-1125.mp3"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _soundType == "click-1125.mp3"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("click-1125"),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _soundType = "tap-2585.mp3"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _soundType == "tap-2585.mp3"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("tap-2585"),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _soundType = "select-3124.mp3"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _soundType == "select-3124.mp3"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("select-3124"),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 🔹 Contenedor visual ping-pong NUEVO
          Container(
            height: 400,
            color: Colors.grey[200],
            child: AnimatedAlign(
              alignment: _animationType == "horizontal"
                  ? (_selectedSide == "right"
                        ? Alignment.centerLeft
                        : Alignment.centerRight)
                  : _animationType == "vertical"
                  ? (_selectedSide == "right"
                        ? Alignment.topCenter
                        : Alignment.bottomCenter)
                  : _animationType == "diagonal-right"
                  ? (_selectedSide == "right"
                        ? Alignment.topLeft
                        : Alignment.bottomRight)
                  : (_selectedSide == "right"
                        ? Alignment.topRight
                        : Alignment.bottomLeft),
              duration: Duration(milliseconds: _frequencyMs),
              curve: Curves.linear,
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botones para cambiar animación
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _animationType = "horizontal"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _animationType == "horizontal"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("Izquierda → Derecha"),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _animationType = "vertical"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _animationType == "vertical"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("Arriba → Abajo"),
              ),
              ElevatedButton(
                onPressed: () =>
                    setState(() => _animationType = "diagonal-right"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _animationType == "diagonal-right"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("Diagonal ↘"),
              ),
              ElevatedButton(
                onPressed: () =>
                    setState(() => _animationType = "diagonal-left"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _animationType == "diagonal-left"
                      ? Colors.blue
                      : Colors.grey,
                ),
                child: const Text("Diagonal ↙"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnect,
        ),
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
