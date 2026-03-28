import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/remote_control.dart';
import '../utils/remote_templates.dart';

class DeviceType {
  final String name;
  final String type;
  final IconData icon;
  DeviceType({required this.name, required this.type, required this.icon});
}

class SelectDeviceTypePage extends StatelessWidget {
  final BluetoothConnection connection;
  // --- UPDATED: Pass in names for validation ---
  final List<String> existingNames;

  SelectDeviceTypePage({
    super.key,
    required this.connection,
    required this.existingNames,
  });

  final List<DeviceType> deviceTypes = [
    DeviceType(name: 'TV', type: 'TV', icon: Icons.tv),
    DeviceType(name: 'AC', type: 'AC', icon: Icons.ac_unit),
    DeviceType(name: 'Fan', type: 'FAN', icon: Icons.air),
    DeviceType(name: 'Speaker', type: 'SPEAKER', icon: Icons.speaker),
    DeviceType(name: 'Setup Box', type: 'BOX', icon: Icons.connected_tv),
    // DeviceType(name: 'Other', type: 'OTHER', icon: Icons.settings_remote),
  ];

  void _onDeviceTypeSelected(BuildContext context, DeviceType device) {
    final TextEditingController nameController = TextEditingController(text: 'New ${device.name}');

    showDialog(
      context: context,
      barrierDismissible: false,
      // --- UPDATED: Use StatefulBuilder to show error text ---
      builder: (dialogContext) {
        String? errorText; // To hold the error message
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('New ${device.name} Remote'),
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Remote Name',
                  errorText: errorText, // Display error here
                ),
                autofocus: true,
                onTap: () => nameController.selectAll(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final remoteName = nameController.text.trim();

                    // --- 1. Validation Logic ---
                    if (remoteName.isEmpty) {
                      setDialogState(() {
                        errorText = "Name cannot be empty.";
                      });
                      return;
                    }
                    if (existingNames.contains(remoteName.toLowerCase())) {
                      setDialogState(() {
                        errorText = "This name is already taken.";
                      });
                      return;
                    }

                    // --- 2. If valid, create the remote ---
                    final List<String> buttons = RemoteTemplates.getButtonsForTemplate(device.type);
                    final newRemote = RemoteControl(
                      name: remoteName,
                      deviceType: device.type,
                      buttons: buttons,
                    );

                    // 3. Pop the dialog
                    Navigator.of(dialogContext).pop();

                    // 4. Pop this page and return the new remote
                    Navigator.of(context).pop(newRemote);
                  },
                  child: const Text('Save & Configure'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device Type'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: deviceTypes.length,
          itemBuilder: (context, index) {
            final device = deviceTypes[index];
            return Card(
              elevation: 2,
              child: InkWell(
                onTap: () => _onDeviceTypeSelected(context, device),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(device.icon, size: 50, color: Theme.of(context).primaryColor),
                    const SizedBox(height: 12),
                    Text(device.name, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Helper to select all text in the dialog
extension SelectAllExtension on TextEditingController {
  void selectAll() {
    if (text.isEmpty) return;
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}