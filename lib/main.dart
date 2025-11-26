import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const TravelNoteApp());

class TravelNoteApp extends StatelessWidget {
  const TravelNoteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TravelNote',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    ),
    home: const Home(),
  );
}

class DiaryEntry {
  final String id;
  final String title;
  final Uint8List? imageBytes;
  final DateTime createdAt;
  final double? lat;
  final double? lng;
  DiaryEntry({
    required this.id,
    required this.title,
    this.imageBytes,
    required this.createdAt,
    this.lat,
    this.lng,
  });
  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "imageBytes": imageBytes != null ? base64Encode(imageBytes!) : null,
    "createdAt": createdAt.toIso8601String(),
    "lat": lat,
    "lng": lng,
  };
  static DiaryEntry fromJson(Map<String, dynamic> j) => DiaryEntry(
    id: j['id'],
    title: j['title'],
    imageBytes: j['imageBytes'] != null ? base64Decode(j['imageBytes']) : null,
    createdAt: DateTime.parse(j['createdAt']),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  final _diary = <DiaryEntry>[];
  bool _loading = true;
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Geolocator.requestPermission();
    try {
      _pos = await Geolocator.getCurrentPosition();
    } catch (_) {}
    print(_pos);
    final prefs = await SharedPreferences.getInstance();
    final rawString = prefs.getString('diary');
    if (rawString != null) {
      final raw = jsonDecode(rawString) as List;
      _diary
        ..clear()
        ..addAll(raw.cast<Map<String, dynamic>>().map(DiaryEntry.fromJson));
    }
    setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'diary',
      jsonEncode(_diary.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final titleController = TextEditingController();
    XFile? picked;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New diary entry',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async => picked = await ImagePicker()
                        .pickImage(source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Pick photo'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async => picked = await ImagePicker()
                        .pickImage(source: ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    Uint8List? imageBytes;
    if (picked != null) {
      imageBytes = await picked!.readAsBytes();
    }
    final pos = _pos ?? await Geolocator.getCurrentPosition();
    setState(
      () => _diary.add(
        DiaryEntry(
          id: const Uuid().v4(),
          title: title,
          imageBytes: imageBytes,
          createdAt: DateTime.now(),
          lat: pos.latitude,
          lng: pos.longitude,
        ),
      ),
    );
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _MapTab(position: _pos, entries: _diary),
      _DiaryTab(entries: _diary, onAdd: () => _addEntry(context)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('TravelNote')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            label: 'Diary',
          ),
        ],
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _addEntry(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({required this.position, required this.entries});
  final Position? position;
  final List<DiaryEntry> entries;
  @override
  Widget build(BuildContext context) {
    final center = position != null
        ? LatLng(position!.latitude, position!.longitude)
        : const LatLng(0, 0);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: position == null ? 1 : 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.travel_note',
        ),
        MarkerLayer(
          markers: [
            if (position != null)
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: Colors.red),
              ),
            ...entries
                .where((e) => e.lat != null && e.lng != null)
                .map(
                  (e) => Marker(
                    point: LatLng(e.lat!, e.lng!),
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.place, color: Colors.blue),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _DiaryTab extends StatelessWidget {
  const _DiaryTab({required this.entries, required this.onAdd});
  final List<DiaryEntry> entries;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('No entries yet. Add your first memory.'),
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries.reversed.toList()[i];
        return ListTile(
          leading: e.imageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    e.imageBytes!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.book_outlined),
          title: Text(e.title),
          subtitle: Text('${e.createdAt.toLocal()}'),
        );
      },
    );
  }
}
