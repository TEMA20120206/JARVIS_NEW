import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'J.A.R.V.I.S. Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B4D8),
          secondary: Color(0xFF00F5D4),
        ),
      ),
      home: const JarvisHome(),
    );
  }
}

class JarvisHome extends StatefulWidget {
  const JarvisHome({super.key});
  @override
  State<JarvisHome> createState() => _JarvisHomeState();
}

class _JarvisHomeState extends State<JarvisHome> {
  String _status = 'J.A.R.V.I.S. Инициализация...';
  bool _isLoading = false;

  // ── ЗАМЕНИ НА СВОИ ДАННЫЕ ──
  final String _macAddress = '30:C5:99:28:8B:2D';
  final String _serverUrl = 'http://192.168.0.110:5000/start-game';
  // ───────────────────────────

  void _setStatus(String text) => setState(() => _status = text);

  Future<void> _sendWol() async {
    setState(() => _isLoading = true);
    _setStatus('Отправка WoL пакета...');
    try {
      final mac = _macAddress.replaceAll(RegExp(r'[:\-]'), '');
      final macBytes = List.generate(6, (i) => int.parse(mac.substring(i * 2, i * 2 + 2), radix: 16));
      final packet = Uint8List(102);
      for (int i = 0; i < 6; i++) packet[i] = 0xFF;
      for (int i = 1; i <= 16; i++) {
        for (int j = 0; j < 6; j++) packet[i * 6 + j] = macBytes[j];
      }
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(packet, InternetAddress('255.255.255.255'), 9);
      socket.close();
      _setStatus('WoL пакет отправлен!');
    } catch (e) {
      _setStatus('Ошибка WoL: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sendHttpRequest() async {
    setState(() => _isLoading = true);
    _setStatus('Запрос на запуск CS...');
    try {
      final response = await http.get(Uri.parse(_serverUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _setStatus('Команда выполнена!');
      } else {
        _setStatus('Код сервера: ${response.statusCode}');
      }
    } catch (e) {
      _setStatus('Ошибка сети: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text('J.A.R.V.I.S.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8), letterSpacing: 8)),
              const Text('CONTROLLER', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF00F5D4), letterSpacing: 6)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.3))),
                child: Text(_status, textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF00B4D8), fontSize: 16))),
              const SizedBox(height: 40),
              _JarvisButton(label: 'ВКЛЮЧИТЬ ПК (WOL)', icon: Icons.power_settings_new,
                color: const Color(0xFF0077B6), onPressed: _isLoading ? null : _sendWol),
              const SizedBox(height: 16),
              _JarvisButton(label: 'ЗАПУСТИТЬ CS', icon: Icons.sports_esports,
                color: const Color(0xFF00796B), onPressed: _isLoading ? null : _sendHttpRequest),
              const Spacer(),
              if (_isLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF00B4D8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _JarvisButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  const _JarvisButton({required this.label, required this.icon, required this.color, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 18, letterSpacing: 1.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }
}
