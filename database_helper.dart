import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'person.dart';
import 'group.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'face_recognition.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE persons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            surname TEXT NOT NULL,
            contact TEXT NOT NULL,
            faceJpg BLOB NOT NULL,
            templates BLOB NOT NULL,
            groupId INTEGER,
            FOREIGN KEY(groupId) REFERENCES groups(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // GROUP METHODS

  Future<int> insertGroup(Group group) async {
    final db = await database;
    return await db.insert('groups', group.toMap());
  }

  Future<List<Group>> getGroups() async {
    final db = await database;
    final result = await db.query('groups');
    return result.map((g) => Group.fromMap(g)).toList();
  }

  Future<int> updateGroup(Group group) async {
    final db = await database;
    return await db.update('groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<int> deleteGroup(int id) async {
    final db = await database;
    return await db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  // PERSON METHODS

  Future<int> insertPerson(Person person) async {
    final db = await database;
    return await db.insert('persons', person.toMap());
  }

  Future<List<Person>> getPersonsByGroup(int groupId) async {
    final db = await database;
    final result = await db.query('persons', where: 'groupId = ?', whereArgs: [groupId]);
    return result.map((p) => Person.fromMap(p)).toList();
  }

  Future<int> updatePerson(Person person) async {
    final db = await database;
    return await db.update('persons', person.toMap(), where: 'id = ?', whereArgs: [person.id]);
  }

  Future<int> deletePerson(int id) async {
    final db = await database;
    return await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }
}
