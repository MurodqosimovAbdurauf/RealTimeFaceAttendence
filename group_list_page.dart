import 'package:flutter/material.dart';
import 'group.dart';
import 'database_helper.dart';

class GroupListPage extends StatefulWidget {
  final Function(Group) onGroupSelected;
  const GroupListPage({super.key, required this.onGroupSelected});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<Group> _groups = [];
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper().getGroups();
    setState(() {
      _groups = groups;
    });
  }

  void _addGroup() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Enter group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                final newGroup = Group(name: name, description: '');
                await DatabaseHelper().insertGroup(newGroup);
                Navigator.pop(context);
                _loadGroups();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _editGroup(Group group) {
    final controller = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = Group(id: group.id, name: controller.text, description: group.description);
              await DatabaseHelper().updateGroup(updated);
              Navigator.pop(context);
              _loadGroups();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper().deleteGroup(group.id!);
              Navigator.pop(context);
              _loadGroups();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addGroup,
          )
        ],
      ),
      body: _groups.isEmpty
          ? const Center(child: Text('No groups yet.'))
          : ListView.builder(
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          return ListTile(
            title: Text(group.name),
            onTap: () => widget.onGroupSelected(group),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editGroup(group),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteGroup(group),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
