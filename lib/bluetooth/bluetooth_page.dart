import 'dart:async';
import 'dart:io';

import 'package:application_desktop_ble/bluetooth/peripheral_page.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final CentralManager _manager = CentralManager();
  final List<DiscoveredEventArgs> _discoveries = [];
  bool _discovering = false;

  StreamSubscription? _stateSub;
  StreamSubscription? _discoveredSub;

  @override
  void initState() {
    super.initState();

    // Escuchar cambios de estado de BLE
    _stateSub = _manager.stateChanged.listen((eventArgs) async {
      if (eventArgs.state == BluetoothLowEnergyState.unauthorized &&
          Platform.isAndroid) {
        await _manager.authorize();
      }
      setState(() {});
    });

    // Escuchar dispositivos descubiertos
    _discoveredSub = _manager.discovered.listen((eventArgs) {
      final index = _discoveries.indexWhere(
        (d) => d.peripheral == eventArgs.peripheral,
      );
      if (index < 0) {
        _discoveries.add(eventArgs);
      } else {
        _discoveries[index] = eventArgs;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _discoveredSub?.cancel();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    _discoveries.clear();
    await _manager.startDiscovery();
    setState(() => _discovering = true);
  }

  Future<void> _stopDiscovery() async {
    await _manager.stopDiscovery();
    setState(() => _discovering = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = _manager.state;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('BLE Demo'),
        actions: [
          if (state == BluetoothLowEnergyState.poweredOn)
            ElevatedButton(
              onPressed: _discovering ? _stopDiscovery : _startDiscovery,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[200],
              ),
              child: Text(_discovering ? "STOP" : "SCAN"),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(BluetoothLowEnergyState state) {
    if (state == BluetoothLowEnergyState.unauthorized &&
        (Platform.isAndroid || Platform.isIOS)) {
      return Center(
        child: ElevatedButton(
          onPressed: () => _manager.showAppSettings(),
          child: const Text("Grant permissions"),
        ),
      );
    }

    if (state != BluetoothLowEnergyState.poweredOn) {
      return Center(child: Text("State: $state"));
    }

    if (_discoveries.isEmpty) {
      return const Center(child: Text("No devices found"));
    }

    return ListView.separated(
      itemCount: _discoveries.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, index) {
        final discovery = _discoveries[index];
        final name = discovery.advertisement.name ?? "Unnamed";
        final uuid = discovery.peripheral.uuid;
        return ListTile(
          title: Text(name),
          subtitle: Text("$uuid"),
          trailing: Text("${discovery.rssi} dBm"),
          onTap: () async {
            // Aquí podrías conectarte al dispositivo
            debugPrint("Tap en $uuid");

            // Ir a pantalla de conexión
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PeripheralPage(
                  peripheral: discovery.peripheral,
                  name: name,
                ),
              ),
            ).then((resultado) {
              _startDiscovery();
            });
          },
        );
      },
    );
  }
}
