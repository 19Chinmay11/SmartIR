import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class AddRemotePage extends StatefulWidget {
  final BluetoothConnection connection;
  // --- MODIFIED: Callback signature changed ---
  final Function(String, String) onAddRemote; // (remoteName, deviceType)
  // --- NEW ---
  final String deviceType;
  final String suggestedName;

  const AddRemotePage({
    super.key,
    required this.connection,
    required this.onAddRemote,
    required this.deviceType,
    required this.suggestedName,
  });

  @override
  State<AddRemotePage> createState() => _AddRemotePageState();
}

class _AddRemotePageState extends State<AddRemotePage> {
  // --- MODIFIED: Controller is initialized in initState ---
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // --- NEW: Set initial text from suggestedName ---
    _nameController = TextEditingController(text: widget.suggestedName);
  }

  void _saveRemote() {
    final remoteName = _nameController.text.trim();
    if (remoteName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Remote name cannot be empty.")));
      return;
    }
    try {
      String command = "ADD_REMOTE:$remoteName\n"; // This command can still be sent
      widget.connection.output.add(Uint8List.fromList(utf8.encode(command)));
      widget.connection.output.allSent;

      // --- MODIFIED: Pass deviceType back to HomePage ---
      widget.onAddRemote(remoteName, widget.deviceType);

      // --- MODIFIED: Pop all the way back to the home page ---
      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending data: $e")));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Remote'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Remote Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              // --- NEW: Select all text on focus ---
              onTap: () => _nameController.selectAll(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveRemote,
              child: const Text('Save Remote'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW: Helper to select all text ---
extension SelectAllExtension on TextEditingController {
  void selectAll() {
    if (text.isEmpty) return;
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}