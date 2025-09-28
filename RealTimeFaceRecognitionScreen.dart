import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart'; // <-- Qo‘shildi
import 'group.dart';
import 'person.dart';
import 'database_helper.dart';
import 'facedetectionview.dart';

class RealTimeFaceRecognitionScreen extends StatefulWidget {
  const RealTimeFaceRecognitionScreen({super.key});

  @override
  State<RealTimeFaceRecognitionScreen> createState() =>
      _RealTimeFaceRecognitionScreenState();
}

class _RealTimeFaceRecognitionScreenState
    extends State<RealTimeFaceRecognitionScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Group> groupList = [];
  Group? selectedGroup;
  List<Person> selectedGroupPersons = [];
  Map<int, bool> attendance = {};
  bool isCameraRunning = false;
  int selectedCameraLens = 1; // 0 = back, 1 = front

  @override
  void initState() {
    super.initState();
    initializeSettings();
  }

  Future<void> initializeSettings() async {
    await requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    selectedCameraLens = prefs.getInt("camera_lens") ?? 1;
    await prefs.setInt("camera_lens", selectedCameraLens);
    loadGroups();
  }

  Future<void> requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request(); // qo‘shimcha ruxsat
  }

  Future<void> loadGroups() async {
    final groups = await dbHelper.getGroups();
    setState(() {
      groupList = groups;
      if (groups.isNotEmpty) {
        selectedGroup = groups.first;
        loadPersonsForGroup();
      }
    });
  }

  Future<void> loadPersonsForGroup() async {
    if (selectedGroup != null) {
      final persons = await dbHelper.getPersonsByGroup(selectedGroup!.id!);
      setState(() {
        selectedGroupPersons = persons;
        attendance = {for (var p in persons) p.id!: false};
      });
    }
  }

  void toggleCamera() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("camera_lens", selectedCameraLens);
    setState(() {
      isCameraRunning = !isCameraRunning;
    });
  }

  void switchCameraLens() async {
    setState(() {
      selectedCameraLens = selectedCameraLens == 1 ? 0 : 1;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("camera_lens", selectedCameraLens);

    if (isCameraRunning) {
      setState(() {
        isCameraRunning = false;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        isCameraRunning = true;
      });
    }
  }

  Future<void> exportAttendanceToExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Attendance'];

    sheet.appendRow(['ID', 'Name', 'Surname', 'Status', 'DateTime']);

    final now = DateTime.now().toString();

    for (var person in selectedGroupPersons) {
      final status = attendance[person.id!] == true ? 'Present' : 'Absent';
      sheet.appendRow([
        person.id,
        person.name,
        person.surname,
        status,
        now,
      ]);
    }

    final directory = await getExternalStorageDirectory();
    final filePath =
        '${directory!.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.encode();
    final file = File(filePath);
    await file.writeAsBytes(fileBytes!);

    // Faylni ochish
    await OpenFile.open(file.path);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel file saved and opened: $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(selectedCameraLens == 1
                ? Icons.camera_front
                : Icons.camera_rear),
            onPressed: switchCameraLens,
            tooltip: 'Switch Camera',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: exportAttendanceToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: groupList.length,
              itemBuilder: (context, index) {
                final group = groupList[index];
                final isSelected = selectedGroup?.id == group.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedGroup = group;
                      loadPersonsForGroup();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.name,
                      style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey[800]),
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: toggleCamera,
            child: Text(isCameraRunning ? 'STOP CAMERA' : 'START CAMERA'),
          ),
          if (isCameraRunning && selectedGroupPersons.isNotEmpty)
            Expanded(
              flex: 2,
              child: FaceRecognitionView(
                personList: selectedGroupPersons,
                onRecognized: (recognizedName) {
                  final matches = selectedGroupPersons
                      .where((p) => p.name == recognizedName);
                  if (matches.isNotEmpty) {
                    final matchedPerson = matches.first;
                    setState(() {
                      attendance[matchedPerson.id!] = true;
                    });
                  }
                },
              ),
            ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: selectedGroupPersons.length,
              itemBuilder: (context, index) {
                final person = selectedGroupPersons[index];
                final isPresent = attendance[person.id!] == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: MemoryImage(person.faceJpg),
                  ),
                  title: Text('${person.name} ${person.surname}'),
                  subtitle: Text(person.contact),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isPresent ? Colors.green : Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        attendance[person.id!] = !isPresent;
                      });
                    },
                    child: Text(isPresent ? 'Present' : 'Absent'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
