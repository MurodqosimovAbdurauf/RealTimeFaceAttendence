import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'group.dart';
import 'person.dart';
import 'database_helper.dart';

class AddPersonToGroupPage extends StatefulWidget {
  final FacesdkPlugin faceSdkPlugin;
  const AddPersonToGroupPage({Key? key, required this.faceSdkPlugin}) : super(key: key);

  @override
  State<AddPersonToGroupPage> createState() => _AddPersonToGroupPageState();
}

class _AddPersonToGroupPageState extends State<AddPersonToGroupPage> {
  List<Group> _groups = [];
  List<Person> _members = [];
  Group? _selectedGroup;
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _contactController = TextEditingController();
  Uint8List? _faceJpg;
  Uint8List? _templates;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper().getGroups();
    setState(() {
      _groups = groups;
      if (_groups.isNotEmpty && _selectedGroup == null) {
        _selectedGroup = _groups.first;
        _loadMembers(_selectedGroup!.id!);
      }
    });
  }

  Future<void> _loadMembers(int groupId) async {
    final members = await DatabaseHelper().getPersonsByGroup(groupId);
    setState(() {
      _members = members;
    });
  }

  Future<void> _createGroupDialog() async {
    final TextEditingController _groupNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Group"),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(labelText: 'Group Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _groupNameController.text.trim();
              if (name.isNotEmpty) {
                final newGroup = Group(name: name, description: "");
                try {
                  final id = await DatabaseHelper().insertGroup(newGroup);
                  Navigator.pop(context);
                  await _loadGroups();
                  setState(() {
                    _selectedGroup = _groups.firstWhere((g) => g.id == id);
                    _loadMembers(_selectedGroup!.id!);
                  });
                } catch (e) {
                  Fluttertoast.showToast(msg: "Error creating group: $e");
                }
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  void _editGroupDialog(Group group) {
    final TextEditingController controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Group"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Group Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                final updated = Group(id: group.id, name: controller.text, description: "");
                await DatabaseHelper().updateGroup(updated);
                Navigator.pop(context);
                _loadGroups();
              },
              child: const Text("Save")
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper().deleteGroup(group.id!);
              Navigator.pop(context);
              _loadGroups();
            },
            child: const Text("Delete"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          )
        ],
      ),
    );
  }

  Future<void> _pickImageAndDetectFace() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final rotatedImage = await FlutterExifRotation.rotateImage(path: image.path);
    final faces = await widget.faceSdkPlugin.extractFaces(rotatedImage.path);

    if (faces.isEmpty) {
      Fluttertoast.showToast(msg: "No face detected!");
      return;
    }

    setState(() {
      _faceJpg = faces[0]['faceJpg'];
      _templates = faces[0]['templates'];
    });
  }

  Future<void> _savePerson() async {
    if (_selectedGroup == null) {
      Fluttertoast.showToast(msg: "Please select a group.");
      return;
    }
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty || _contactController.text.isEmpty || _faceJpg == null || _templates == null) {
      Fluttertoast.showToast(msg: "Please complete all fields and select a face.");
      return;
    }

    final person = Person(
      name: _nameController.text,
      surname: _surnameController.text,
      contact: _contactController.text,
      faceJpg: _faceJpg!,
      templates: _templates!,
      groupId: _selectedGroup!.id!,
    );
    await DatabaseHelper().insertPerson(person);
    Fluttertoast.showToast(msg: "Person saved.");
    _nameController.clear();
    _surnameController.clear();
    _contactController.clear();
    setState(() {
      _faceJpg = null;
      _templates = null;
    });
    _loadMembers(_selectedGroup!.id!);
  }

  void _editPersonDialog(Person person) {
    final nameCtrl = TextEditingController(text: person.name);
    final surnameCtrl = TextEditingController(text: person.surname);
    final contactCtrl = TextEditingController(text: person.contact);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Person"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: surnameCtrl, decoration: const InputDecoration(labelText: 'Surname')),
            TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final updated = person.copyWith(
                name: nameCtrl.text,
                surname: surnameCtrl.text,
                contact: contactCtrl.text,
              );
              await DatabaseHelper().updatePerson(updated);
              Navigator.pop(context);
              _loadMembers(_selectedGroup!.id!);
            },
            child: const Text("Save"),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper().deletePerson(person.id!);
              Navigator.pop(context);
              _loadMembers(_selectedGroup!.id!);
            },
            child: const Text("Delete"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Group & Person Manager"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Groups:", style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createGroupDialog,
                )
              ],
            ),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final isSelected = group.id == _selectedGroup?.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InputChip(
                      label: Text(group.name),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedGroup = group;
                          _loadMembers(group.id!);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text("Add Member"),
                  onPressed: _selectedGroup == null ? null : () => _showAddMemberForm(),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Group"),
                  onPressed: _selectedGroup == null ? null : () => _editGroupDialog(_selectedGroup!),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text("Members:"),
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final person = _members[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: MemoryImage(person.faceJpg)),
                    title: Text("${person.name} ${person.surname}"),
                    subtitle: Text(person.contact),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editPersonDialog(person),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showAddMemberForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextFormField(
                  controller: _surnameController,
                  decoration: const InputDecoration(labelText: 'Surname'),
                ),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(labelText: 'Contact'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Pick Face"),
                  onPressed: _pickImageAndDetectFace,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text("Save Person to Group"),
                  onPressed: _savePerson,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
