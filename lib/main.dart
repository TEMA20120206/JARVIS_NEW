import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(const JarvisApp());

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'J.A.R.V.I.S.',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF00B4D8), secondary: Color(0xFF00F5D4)),
    ),
    home: const JarvisHome(),
  );
}

// ── НАСТРОЙКИ ────────────────────────────────────────────────
const String kMac = '30:C5:99:28:8B:2D';   // ← ЗАМЕНИ MAC ПК
const String kIp  = '192.168.0.110';         // ← ЗАМЕНИ IP ПК
const int    kPort = 5000;
String get baseUrl => 'http://$kIp:$kPort';
// ─────────────────────────────────────────────────────────────

class JarvisHome extends StatefulWidget {
  const JarvisHome({super.key});
  @override
  State<JarvisHome> createState() => _JarvisHomeState();
}

class _JarvisHomeState extends State<JarvisHome> {
  int _tab = 0;
  final _pages = const [HomePage(), GamesPage(), StatusPage()];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _pages[_tab],
    bottomNavigationBar: NavigationBar(
      backgroundColor: const Color(0xFF0D1B2A),
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
        NavigationDestination(icon: Icon(Icons.sports_esports), label: 'Игры'),
        NavigationDestination(icon: Icon(Icons.monitor_heart), label: 'Статус'),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ГЛАВНАЯ
// ══════════════════════════════════════════════════════════════
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Готов к работе';
  bool _loading = false;

  void _set(String s) => setState(() => _status = s);

  Future<void> _wol() async {
    setState(() => _loading = true);
    _set('Отправка WoL...');
    try {
      final mac = kMac.replaceAll(RegExp(r'[:\-]'), '');
      final macBytes = List.generate(6, (i) => int.parse(mac.substring(i*2, i*2+2), radix: 16));
      final pkt = Uint8List(102);
      for (int i = 0; i < 6; i++) pkt[i] = 0xFF;
      for (int i = 1; i <= 16; i++) for (int j = 0; j < 6; j++) pkt[i*6+j] = macBytes[j];
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      s.broadcastEnabled = true;
      s.send(pkt, InternetAddress('255.255.255.255'), 9);
      s.close();
      _set('WoL пакет отправлен ✓');
    } catch (e) { _set('Ошибка: $e'); }
    setState(() => _loading = false);
  }

  Future<void> _cmd(String path, String msg) async {
    setState(() { _loading = true; _status = msg; });
    try {
      final r = await http.get(Uri.parse('$baseUrl$path')).timeout(const Duration(seconds: 5));
      final data = jsonDecode(r.body);
      _set(data['message'] ?? 'OK');
    } catch (e) { _set('Ошибка сети: $e'); }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 10),
      const Text('J.A.R.V.I.S.', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8), letterSpacing: 8)),
      const Text('CONTROLLER', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xFF00F5D4), letterSpacing: 6)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.3))),
        child: Text(_status, textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF00B4D8), fontSize: 15))),
      const SizedBox(height: 28),
      _Btn('ВКЛЮЧИТЬ ПК', Icons.power_settings_new, const Color(0xFF0077B6),
        _loading ? null : _wol),
      const SizedBox(height: 12),
      _Btn('ВЫКЛЮЧИТЬ ПК', Icons.power_off, const Color(0xFF7B2D00),
        _loading ? null : () => _showConfirm('Выключить ПК?', () => _cmd('/shutdown', 'Выключение...'))),
      const SizedBox(height: 12),
      _Btn('ПЕРЕЗАГРУЗКА', Icons.restart_alt, const Color(0xFF5A4000),
        _loading ? null : () => _showConfirm('Перезагрузить ПК?', () => _cmd('/reboot', 'Перезагрузка...'))),
      const SizedBox(height: 12),
      _Btn('СОН', Icons.bedtime, const Color(0xFF1A3A4A),
        _loading ? null : () => _cmd('/sleep', 'Уходим в сон...')),
      const Spacer(),
      if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFF00B4D8))),
    ]),
  ));

  void _showConfirm(String text, VoidCallback onOk) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      title: Text(text, style: const TextStyle(color: Color(0xFF00B4D8))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: () { Navigator.pop(context); onOk(); },
          child: const Text('Да', style: TextStyle(color: Colors.redAccent))),
      ],
    ));
}

// ══════════════════════════════════════════════════════════════
// ИГРЫ
// ══════════════════════════════════════════════════════════════
class GamesPage extends StatefulWidget {
  const GamesPage({super.key});
  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> with SingleTickerProviderStateMixin {
  late TabController _tc;
  List _steam = [], _epic = [];
  bool _loadSteam = false, _loadEpic = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _fetchSteam();
    _fetchEpic();
  }

  Future<void> _fetchSteam() async {
    setState(() => _loadSteam = true);
    try {
      final r = await http.get(Uri.parse('$baseUrl/games/steam')).timeout(const Duration(seconds: 8));
      setState(() => _steam = jsonDecode(r.body)['games'] ?? []);
    } catch (_) {}
    setState(() => _loadSteam = false);
  }

  Future<void> _fetchEpic() async {
    setState(() => _loadEpic = true);
    try {
      final r = await http.get(Uri.parse('$baseUrl/games/epic')).timeout(const Duration(seconds: 8));
      setState(() => _epic = jsonDecode(r.body)['games'] ?? []);
    } catch (_) {}
    setState(() => _loadEpic = false);
  }

  Future<void> _launch(String url) async {
    try {
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Игра запущена!'), backgroundColor: Color(0xFF00796B)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _gameList(List games, bool loading, String prefix) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00B4D8)));
    if (games.isEmpty) return const Center(child: Text('Игры не найдены', style: TextStyle(color: Colors.white54)));
    final filtered = games.where((g) =>
      (g['name'] as String).toLowerCase().contains(_search.toLowerCase())).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final g = filtered[i];
        return ListTile(
          leading: const Icon(Icons.videogame_asset, color: Color(0xFF00B4D8)),
          title: Text(g['name'], style: const TextStyle(color: Colors.white)),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow, color: Color(0xFF00F5D4)),
            onPressed: () {
              final url = prefix == 'steam'
                ? '$baseUrl/games/steam/launch/${g["appid"]}'
                : '$baseUrl/games/epic/launch/${g["app_name"]}';
              _launch(url);
            }),
        );
      });
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    const Padding(padding: EdgeInsets.all(16),
      child: Text('ИГРЫ', style: TextStyle(fontSize: 20, letterSpacing: 4,
        color: Color(0xFF00B4D8), fontWeight: FontWeight.bold))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Поиск...', prefixIcon: const Icon(Icons.search),
          filled: true, fillColor: const Color(0xFF0D1B2A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        onChanged: (v) => setState(() => _search = v))),
    TabBar(controller: _tc,
      tabs: [
        Tab(text: 'Steam (${_steam.length})'),
        Tab(text: 'Epic (${_epic.length})'),
      ]),
    Expanded(child: TabBarView(controller: _tc, children: [
      _gameList(_steam, _loadSteam, 'steam'),
      _gameList(_epic, _loadEpic, 'epic'),
    ])),
  ]));
}

// ══════════════════════════════════════════════════════════════
// СТАТУС ПК
// ══════════════════════════════════════════════════════════════
class StatusPage extends StatefulWidget {
  const StatusPage({super.key});
  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String _error = '';

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final r = await http.get(Uri.parse('$baseUrl/status')).timeout(const Duration(seconds: 5));
      setState(() => _data = jsonDecode(r.body));
    } catch (e) { setState(() => _error = 'ПК недоступен'); }
    setState(() => _loading = false);
  }

  Widget _stat(String label, String value, double percent, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: percent.clamp(0, 1), minHeight: 8,
        backgroundColor: const Color(0xFF1A2A3A),
        valueColor: AlwaysStoppedAnimation(color))),
    ]));

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('СТАТУС ПК', style: TextStyle(fontSize: 20, letterSpacing: 4,
            color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF00F5D4)), onPressed: _fetch),
        ]),
        const SizedBox(height: 20),
        if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFF00B4D8)))
        else if (_error.isNotEmpty) Center(child: Column(children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16)),
        ]))
        else if (d != null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 12, height: 12, decoration: const BoxDecoration(
              color: Color(0xFF00F5D4), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('ПК онлайн', style: TextStyle(color: Color(0xFF00F5D4), fontSize: 16)),
          ]),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _stat('Процессор', '${d["cpu_percent"]}%', (d["cpu_percent"] as num) / 100,
                (d["cpu_percent"] as num) > 80 ? Colors.red : const Color(0xFF00B4D8)),
              if (d["cpu_temp"] != null)
                _stat('Температура CPU', '${d["cpu_temp"].toStringAsFixed(1)}°C',
                  (d["cpu_temp"] as num) / 100,
                  (d["cpu_temp"] as num) > 80 ? Colors.red : Colors.orange),
              _stat('ОЗУ', '${d["ram_used_gb"]} / ${d["ram_total_gb"]} GB',
                (d["ram_percent"] as num) / 100,
                (d["ram_percent"] as num) > 85 ? Colors.red : const Color(0xFF00F5D4)),
              _stat('Диск C:', '${d["disk_percent"]}% (свободно ${d["disk_free_gb"]} GB)',
                (d["disk_percent"] as num) / 100,
                (d["disk_percent"] as num) > 90 ? Colors.red : Colors.amber),
            ])),
        ],
      ]),
    ));
  }
}

// ══════════════════════════════════════════════════════════════
// КНОПКА
// ══════════════════════════════════════════════════════════════
class _Btn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback? onPressed;
  const _Btn(this.label, this.icon, this.color, this.onPressed);
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed, icon: Icon(icon), label: Text(label,
      style: const TextStyle(fontSize: 16, letterSpacing: 1.2)),
    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
}
