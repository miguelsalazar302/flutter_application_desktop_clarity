import 'dart:typed_data';
import 'dart:convert';
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
  bool _connected = false;

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

  String? _selectedColor;
  String? _selectedSide; // "right" o "left"
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

    if (intensity == null ||
        duration == null ||
        colorIndex == null ||
        _selectedSide == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    final Map<String, dynamic> data = {
      "Dr": _selectedSide,
      "in": intensity,
      "col": colorIndex,
      "Dur": duration,
    };

    // Convertir a JSON string y luego a bytes (igual que en Python)
    final jsonStr = json.encode(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr)); // Usar UTF-8

    debugPrint("✅ Datos enviados al BLE: $jsonStr");

    try {
      //sonido

      //relentice

      //BLE
      await _manager.writeCharacteristic(
        widget.peripheral,
        _writeChar!,
        value: bytes,
        type: GATTCharacteristicWriteType.withResponse,
      );
      debugPrint("✅ Datos enviados al BLE: $data");
    } catch (e) {
      debugPrint("❌ Error enviando al BLE: $e");
    }
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
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: "Seleccione un color",
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
          const SizedBox(height: 16),

          // Card con color elegido
          if (_selectedColor != null)
            Card(
              color: _colors[_selectedColor],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    _selectedColor!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 30),

          // Selección Derecho / Izquierdo en fila
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
                child: const Text("Derecho", style: TextStyle(fontSize: 16)),
              ),
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
                child: const Text("Izquierdo", style: TextStyle(fontSize: 16)),
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
