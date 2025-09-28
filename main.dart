import 'package:flutter/material.dart';
import 'dart:async';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'about.dart';
import 'settings.dart';
import 'person.dart';
import 'personview.dart';
import 'AddPersonToGroupPage.dart';
import 'RealTimeFaceRecognitionScreen.dart';
import 'package:flutter/cupertino.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Face Recognition',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: MyHomePage(title: 'Face Recognition'));
  }
}
// ignore: must_be_immutable
class MyHomePage extends StatefulWidget {
  final String title;
  var personList = <Person>[];

  MyHomePage({super.key, required this.title});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String _warningState = "";
  bool _visibleWarning = false;

  final _facesdkPlugin = FacesdkPlugin();

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    int facepluginState = -1;
    String warningState = "";
    bool visibleWarning = false;

    try {
      if (Platform.isAndroid) {
        await _facesdkPlugin
            .setActivation(
            "j63rQnZifPT82LEDGFa+wzorKx+M55JQlNr+S0bFfvMULrNYt+UEWIsa11V/Wk1bU9Srti0/FQqp"
                "UczeCxFtiEcABmZGuTzNd27XnwXHUSIMaFOkrpNyNE4MHb7HBm5kU/0J/SAMfybICCWyFajuZ4fL"
                "agozJV5DPKj22oFVaueWMjO/9fMvcps4u1AIiHH2rjP4mEYfiAE8nhHBa1Ou3u/WkXj6jdDafyJo"
                "AFtQHYJYKDU+hcbtCZ3P1f8y1JB5JxOf92ItK4euAt6/OFG9jGfKpo/Fs2mAgwxH3HoWMLJQ16Iy"
                "u2K6boMyDxRQtBJFTiktuJ+ltlay+dVqIi3Jpg==")
            .then((value) => facepluginState = value ?? -1);
      } else {
        await _facesdkPlugin
            .setActivation(
            "nWsdDhTp12Ay5yAm4cHGqx2rfEv0U+Wyq/tDPopH2yz6RqyKmRU+eovPeDcAp3T3IJJYm2LbPSEz"
                "+e+YlQ4hz+1n8BNlh2gHo+UTVll40OEWkZ0VyxkhszsKN+3UIdNXGaQ6QL0lQunTwfamWuDNx7Ss"
                "efK/3IojqJAF0Bv7spdll3sfhE1IO/m7OyDcrbl5hkT9pFhFA/iCGARcCuCLk4A6r3mLkK57be4r"
                "T52DKtyutnu0PDTzPeaOVZRJdF0eifYXNvhE41CLGiAWwfjqOQOHfKdunXMDqF17s+LFLWwkeNAD"
                "PKMT+F/kRCjnTcC8WPX3bgNzyUBGsFw9fcneKA==")
            .then((value) => facepluginState = value ?? -1);
      }

      if (facepluginState == 0) {
        await _facesdkPlugin
            .init()
            .then((value) => facepluginState = value ?? -1);
      }
    } catch (e) {}

    List<Person> personList = await loadAllPersons();
    await SettingsPageState.initSettings();

    final prefs = await SharedPreferences.getInstance();
    int? livenessLevel = prefs.getInt("liveness_level");

    try {
      await _facesdkPlugin
          .setParam({'check_liveness_level': livenessLevel ?? 0});
    } catch (e) {}

    if (!mounted) return;

    if (facepluginState == -1) {
      warningState = "Invalid license!";
      visibleWarning = true;
    } else if (facepluginState == -2) {
      warningState = "License expired!";
      visibleWarning = true;
    } else if (facepluginState == -3) {
      warningState = "Invalid license!";
      visibleWarning = true;
    } else if (facepluginState == -4) {
      warningState = "No activated!";
      visibleWarning = true;
    } else if (facepluginState == -5) {
      warningState = "Init error!";
      visibleWarning = true;
    }

    setState(() {
      _warningState = warningState;
      _visibleWarning = visibleWarning;
      widget.personList = personList;
    });
  }

  Future<Database> createDB() async {
    final database = openDatabase(
      join(await getDatabasesPath(), 'person.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE person(name text, faceJpg blob, templates blob)',
        );
      },
      version: 1,
    );

    return database;
  }

  Future<List<Person>> loadAllPersons() async {
    final db = await createDB();
    final List<Map<String, dynamic>> maps = await db.query('person');
    return List.generate(maps.length, (i) {
      return Person.fromMap(maps[i]);
    });
  }

  Future<void> insertPerson(Person person) async {
    final db = await createDB();
    await db.insert(
      'person',
      person.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    setState(() {
      widget.personList.add(person);
    });
  }

  Future<void> deleteAllPerson() async {
    final db = await createDB();
    await db.delete('person');
    setState(() {
      widget.personList.clear();
    });

    Fluttertoast.showToast(
        msg: "All person deleted!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> deletePerson(index) async {
    final db = await createDB();
    await db.delete('person',
        where: 'name=?', whereArgs: [widget.personList[index].name]);
    setState(() {
      widget.personList.removeAt(index);
    });

    Fluttertoast.showToast(
        msg: "Person removed!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        toolbarHeight: 50,
        centerTitle: true,
      ),
      backgroundColor: const Color.fromRGBO(241, 237, 255, 1.0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Tepadagi asosiy rasm
            SizedBox(
              height: 200,
              width: 300,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/GPTrasm.png"),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Birinchi qator tugmalar - Add Person va Attendance
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageButton(
                  context: context,
                  label: 'Add Person',
                  asset: 'assets/Student.webp',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddPersonToGroupPage(
                          faceSdkPlugin: _facesdkPlugin,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
                _buildImageButton(
                  context: context,
                  label: 'Attendance',
                  asset: 'assets/attendence.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RealTimeFaceRecognitionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Ikkinchi qator tugmalar - Settings va About
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageButton(
                  context: context,
                  label: 'Settings',
                  asset: 'assets/settings.jpg',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsPage(
                          homePageState: this,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
                _buildImageButton(
                  context: context,
                  label: 'About',
                  asset: 'assets/about.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutPage(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // PersonView
            SizedBox(
              height: 350,
              child: Stack(
                children: [
                  PersonView(
                    personList: widget.personList,
                    homePageState: this,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Visibility(
                        visible: _visibleWarning,
                        child: Container(
                          width: double.infinity,
                          height: 40,
                          color: Colors.redAccent,
                          child: Center(
                            child: Text(
                              _warningState,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pastdagi matn
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SAMBHRAM UNIVERSITY',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color.fromARGB(255, 60, 60, 60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Yordamchi metod: rasmli tugma
  Widget _buildImageButton({
    required BuildContext context,
    required String label,
    required String asset,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 120,
      width: 120,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Center(
            child: Image(
              image: AssetImage(asset),
              fit: BoxFit.cover,
              height: 80,
              width: 80,
            ),
          ),
          onPressed: onTap,
        ),
      ),
    );
  }

}
