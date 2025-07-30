import 'dart:async';
import 'dart:typed_data';
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

  double _intensidad = 0.5; // rango 0-1
  double _frecuencia = 0.5; // rango 0-1

  // UUIDs reales del ejemplo JS
  final UUID serviceUUID = UUID.fromString(
    "89248e86-48d1-43df-b25c-5c0e3dfb858f",
  );
  final UUID modeCharUUID = UUID.fromString(
    "66b9319f-992b-412a-8f7e-3424dfbefbf1",
  );
  final UUID zoneCharUUID = UUID.fromString(
    "34b4b3e1-8607-468b-b9fc-261421e8890a",
  );
  final UUID triggerCharUUID = UUID.fromString(
    "b1814cf7-688f-4198-a9e2-9a889d186cf8",
  );
  final UUID intensidadCharUUID = UUID.fromString(
    "6b78dc9f-c104-4d5a-a336-902e8ad78f2c",
  );
  final UUID frecuenciaCharUUID = UUID.fromString(
    "7be2b410-1d3e-4449-8586-9495fc48669c",
  );

  // Características GATT
  GATTCharacteristic? _modeChar;
  GATTCharacteristic? _zoneChar;
  GATTCharacteristic? _triggerChar;
  GATTCharacteristic? _intensidadChar;
  GATTCharacteristic? _frecuenciaChar;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _manager.connect(widget.peripheral);
      final services = await _manager.discoverGATT(widget.peripheral);

      // buscar el servicio principal
      final service = services.firstWhere(
        (s) => s.uuid == serviceUUID,
        orElse: () => throw Exception("Servicio no encontrado"),
      );

      // buscar todas las características
      _modeChar = service.characteristics.firstWhere(
        (c) => c.uuid == modeCharUUID,
        orElse: _throwNotFound,
      );
      _zoneChar = service.characteristics.firstWhere(
        (c) => c.uuid == zoneCharUUID,
        orElse: _throwNotFound,
      );
      _triggerChar = service.characteristics.firstWhere(
        (c) => c.uuid == triggerCharUUID,
        orElse: _throwNotFound,
      );
      _intensidadChar = service.characteristics.firstWhere(
        (c) => c.uuid == intensidadCharUUID,
        orElse: _throwNotFound,
      );
      _frecuenciaChar = service.characteristics.firstWhere(
        (c) => c.uuid == frecuenciaCharUUID,
        orElse: _throwNotFound,
      );

      // Escribir valores iniciales fijos (como el ejemplo JS)
      await _writeFixedValues();

      setState(() => _connected = true);
    } catch (e) {
      debugPrint("Error al conectar: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al conectar: $e")));
    }
  }

  Never _throwNotFound() =>
      throw Exception("Característica requerida no encontrada");

  Future<void> _writeFixedValues() async {
    if (_modeChar == null || _zoneChar == null || _triggerChar == null) return;

    await _manager.writeCharacteristic(
      widget.peripheral,
      _modeChar!,
      value: Uint8List.fromList([0x01]),
      type: GATTCharacteristicWriteType.withResponse,
    );

    await _manager.writeCharacteristic(
      widget.peripheral,
      _zoneChar!,
      value: Uint8List.fromList([0x07]),
      type: GATTCharacteristicWriteType.withResponse,
    );

    await _manager.writeCharacteristic(
      widget.peripheral,
      _triggerChar!,
      value: Uint8List.fromList([0x01]),
      type: GATTCharacteristicWriteType.withResponse,
    );
  }

  Future<void> _disconnect() async {
    await _manager.disconnect(widget.peripheral);
    setState(() => _connected = false);
    Navigator.pop(context);
  }

  Future<void> _sendIntensity() async {
    if (_intensidadChar == null) return;
    final val = (_intensidad * 100).round() + 128;
    await _manager.writeCharacteristic(
      widget.peripheral,
      _intensidadChar!,
      value: Uint8List.fromList([val]),
      type: GATTCharacteristicWriteType.withResponse,
    );
  }

  Future<void> _sendFrequency() async {
    if (_frecuenciaChar == null) return;
    final val = (_frecuencia * 100).round() + 129;
    await _manager.writeCharacteristic(
      widget.peripheral,
      _frecuenciaChar!,
      value: Uint8List.fromList([val]),
      type: GATTCharacteristicWriteType.withResponse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.peripheral.uuid}"),
        actions: [
          if (_connected)
            IconButton(icon: const Icon(Icons.close), onPressed: _disconnect),
        ],
      ),
      body: !_connected
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("Intensidad"),
                  Slider(
                    min: 0,
                    max: 1,
                    divisions: 100,
                    value: _intensidad,
                    onChanged: (v) => setState(() => _intensidad = v),
                    onChangeEnd: (_) => _sendIntensity(),
                  ),
                  const SizedBox(height: 20),
                  const Text("Frecuencia"),
                  Slider(
                    min: 0,
                    max: 1,
                    divisions: 100,
                    value: _frecuencia,
                    onChanged: (v) => setState(() => _frecuencia = v),
                    onChangeEnd: (_) => _sendFrequency(),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _disconnect,
                    child: const Text("Desconectar y volver"),
                  ),
                ],
              ),
            ),
    );
  }
}
