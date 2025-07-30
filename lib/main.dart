import 'package:application_desktop_ble/acrylic/acrylic_page.dart';
import 'package:flutter/material.dart';
import 'package:application_desktop_ble/bluetooth/bluetooth_page.dart';
import 'package:flutter_acrylic/window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Window.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE and Clarity Simple Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MainTabs(),
    );
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;

  // Lista de pantallas
  final List<Widget> _pages = [
    const BluetoothPage(),
    const AcrylicPage(), // Aquí luego pones tu nueva pantalla
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: "BLE"),
          BottomNavigationBarItem(icon: Icon(Icons.widgets), label: "Acrylic"),
        ],
      ),
    );
  }
}
