import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// -----------------------------------------------------------------------------
// 1. Plant Model
// -----------------------------------------------------------------------------
class Plant {
  String name;
  DateTime lastWatered;
  int wateringFrequencyDays;
  String soilType;
  List<DateTime> waterHistory = [];

  Plant({
    required this.name,
    required this.lastWatered,
    this.wateringFrequencyDays = 7,
    this.soilType = 'Well-drained Potting Mix',
  }) {
    waterHistory.add(lastWatered);
  }

  DateTime get nextWateringDate =>
      lastWatered.add(Duration(days: wateringFrequencyDays));

  bool get isOverdue => DateTime.now().isAfter(nextWateringDate);

  String get careTip {
    if (name.toLowerCase().contains('aloe')) {
      return 'Allow soil to dry completely between waterings. Very drought tolerant.';
    } else if (name.toLowerCase().contains('bamboo')) {
      return 'Keep soil consistently moist but not soggy. Prefers filtered light.';
    } else {
      return 'Check soil daily and water when top layer feels dry.';
    }
  }

  String get sunlightNeeds {
    if (name.toLowerCase().contains('aloe')) {
      return 'Bright, direct sunlight is best.';
    } else if (name.toLowerCase().contains('bamboo')) {
      return 'Indirect/Filtered sunlight.';
    } else {
      return 'Bright, indirect sunlight.';
    }
  }

  void markAsWatered() {
    lastWatered = DateTime.now();
    waterHistory.add(lastWatered);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'lastWatered': lastWatered.toIso8601String(),
    'wateringFrequencyDays': wateringFrequencyDays,
    'soilType': soilType,
    'waterHistory': waterHistory.map((d) => d.toIso8601String()).toList(),
  };

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      name: json['name'],
      lastWatered: DateTime.parse(json['lastWatered']),
      wateringFrequencyDays: json['wateringFrequencyDays'],
      soilType: json['soilType'],
    )..waterHistory = (json['waterHistory'] as List)
        .map((e) => DateTime.parse(e))
        .toList();
  }
}

// -----------------------------------------------------------------------------
// 2. Main App
// -----------------------------------------------------------------------------
void main() {
  runApp(const PlantCareApp());
}

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart PlantCare',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const HomeScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Home Screen
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Plant> plants = [];

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('plants');
    if (data != null) {
      final decoded = jsonDecode(data) as List;
      setState(() {
        plants = decoded.map((e) => Plant.fromJson(e)).toList();
      });
    }
  }

  Future<void> _savePlants() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(plants.map((p) => p.toJson()).toList());
    await prefs.setString('plants', data);
  }

  void _addPlant(Plant plant) {
    setState(() {
      plants.add(plant);
      plants.sort((a, b) => a.nextWateringDate.compareTo(b.nextWateringDate));
    });
    _savePlants();
  }

  void _deletePlant(int index) {
    setState(() {
      plants.removeAt(index);
    });
    _savePlants();
  }

  void _updatePlants() {
    setState(() {});
    _savePlants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌱 Smart PlantCare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb),
            tooltip: 'Suggestions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SuggestionsScreen()),
              );
            },
          ),
        ],
      ),
      body: plants.isEmpty
          ? const Center(
        child: Text('No plants yet! Add one 🌿', style: TextStyle(fontSize: 16)),
      )
          : ListView.builder(
        itemCount: plants.length,
        itemBuilder: (context, index) {
          final plant = plants[index];
          final isOverdue = plant.isOverdue;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
            child: ListTile(
              leading: Icon(Icons.local_florist,
                  color: isOverdue ? Colors.red : Colors.green, size: 32),
              title: Text(plant.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(
                'Next Water: ${DateFormat('MMM d').format(plant.nextWateringDate)}\nSoil: ${plant.soilType}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _deletePlant(index),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlantDetailScreen(
                      plant: plant,
                      onUpdate: _updatePlants,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newPlant = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPlantScreen()),
          );
          if (newPlant != null) _addPlant(newPlant);
        },
        label: const Text('Add Plant'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Plant Detail Screen
// -----------------------------------------------------------------------------
class PlantDetailScreen extends StatefulWidget {
  final Plant plant;
  final VoidCallback onUpdate;

  const PlantDetailScreen({super.key, required this.plant, required this.onUpdate});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  void _waterNow() {
    setState(() {
      widget.plant.markAsWatered();
    });
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plant;
    return Scaffold(
      appBar: AppBar(title: Text('${p.name} Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton.icon(
              onPressed: _waterNow,
              icon: const Icon(Icons.water_drop),
              label: const Text('Mark as Watered'),
            ),
            const SizedBox(height: 15),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Next Water Date'),
                subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(p.nextWateringDate)),
              ),
            ),
            _buildTile(Icons.grass, 'Soil Type', p.soilType),
            _buildTile(Icons.wb_sunny, 'Sunlight', p.sunlightNeeds),
            _buildTile(Icons.tips_and_updates, 'Care Tip', p.careTip),
            const SizedBox(height: 15),
            const Text('Watering History (Last 5):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...p.waterHistory.reversed.take(5).map((d) => Text(
              '• ${DateFormat('MMM d, yyyy – hh:mm a').format(d)}',
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle) => Card(
    child: ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    ),
  );
}

// -----------------------------------------------------------------------------
// 5. Add Plant Screen
// -----------------------------------------------------------------------------
class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  int _frequency = 7;
  DateTime _lastWatered = DateTime.now();
  String? _soil = 'Well-drained Potting Mix';

  final _soilTypes = [
    'Well-drained Potting Mix',
    'Cactus/Succulent Mix (Sandy)',
    'Moisture-Retentive Loam',
    'Clay Soil',
    'Acidic Soil',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastWatered,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _lastWatered = picked);
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final plant = Plant(
        name: _name.text,
        lastWatered: _lastWatered,
        wateringFrequencyDays: _frequency,
        soilType: _soil!,
      );
      Navigator.pop(context, plant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Plant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Plant Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_florist),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 20),
              Text('Water every $_frequency days',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _frequency.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => setState(() => _frequency = v.round()),
              ),
              DropdownButtonFormField<String>(
                value: _soil,
                decoration: const InputDecoration(
                    labelText: 'Soil Type', border: OutlineInputBorder()),
                items: _soilTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _soil = v),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text('Last Watered: ${DateFormat('MMM d, yyyy').format(_lastWatered)}'),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Plant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. Suggestions Screen
// -----------------------------------------------------------------------------
class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const climate = 'Hot & Dry';
    const location = 'India (Simulated)';

    final suggestions = {
      'Hot & Dry': ['Aloe Vera', 'Cactus', 'Bougainvillea', 'Rose'],
      'Warm & Humid': ['Bamboo', 'Ferns', 'Money Plant', 'Hibiscus'],
      'Cool & Temperate': ['Tulip', 'Marigold', 'Rosemary'],
    };

    final plants = suggestions[climate]!;

    return Scaffold(
      appBar: AppBar(title: const Text('Plant Suggestions')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(location),
                subtitle: Text('Climate: $climate'),
              ),
            ),
            const SizedBox(height: 15),
            const Text('Recommended Plants:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ...plants.map((p) => ListTile(
              leading: const Icon(Icons.eco, color: Colors.green),
              title: Text(p),
              onTap: () => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Details for $p'))),
            )),
          ],
        ),
      ),
    );
  }
}

