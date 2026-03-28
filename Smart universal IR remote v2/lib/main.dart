import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/remote_control.dart';
import 'screens/remote_control_page.dart';
import 'screens/select_device_type_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'IR Remote Configurator',
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  Stream<Uint8List>? _broadcastStream;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isConnecting = false;
  final List<RemoteControl> _remotes = [];

  // --- Battery State Variables ---
  int _batteryLevel = 0;
  bool _isCharging = false;
  String _messageBuffer = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRemotes();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
      if (state == BluetoothState.STATE_OFF) {
        _enableBluetooth();
      } else {
        _getPairedDevices();
      }
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (state == BluetoothState.STATE_OFF) {
          _isConnected = false;
          _selectedDevice = null;
        } else if (state == BluetoothState.STATE_ON) {
          _getPairedDevices();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FlutterBluetoothSerial.instance.state.then((state) {
        setState(() => _bluetoothState = state);
      });
    }
  }

  Future<void> _enableBluetooth() async {
    await FlutterBluetoothSerial.instance.requestEnable();
  }

  Future<void> _loadRemotes() async {
    final prefs = await SharedPreferences.getInstance();
    final remotesJson = prefs.getStringList('remotes') ?? [];
    setState(() {
      _remotes.clear();
      _remotes.addAll(remotesJson
          .map((jsonString) => RemoteControl.fromJsonString(jsonString))
          .toList());
    });
  }

  Future<void> _saveRemotes() async {
    final prefs = await SharedPreferences.getInstance();
    final remotesJson = _remotes.map((remote) => remote.toJsonString()).toList();
    await prefs.setStringList('remotes', remotesJson);
  }

  void _connect() async {
    if (_selectedDevice == null) {
      _showError("No device selected.");
      return;
    }
    setState(() { _isConnecting = true; });
    try {
      _connection = await BluetoothConnection.toAddress(_selectedDevice!.address);

      // Fix: Ensure we use asBroadcastStream so both HomePage and RemoteControlPage can listen
      _broadcastStream = _connection!.input!.asBroadcastStream();

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });

      _showStatus("Connected to ${_selectedDevice!.name}");

      // Listen for global messages (like Battery) on the Home Page
      _broadcastStream!.listen(_onDataReceived).onDone(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _selectedDevice = null;
            _batteryLevel = 0;
            _isCharging = false;
          });
          _showStatus("Device disconnected.");
        }
      });
    } catch (e) {
      _showError("Failed to connect InfraSmart Device");
      setState(() { _isConnecting = false; });
    }
  }

  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data);
    _messageBuffer += dataString;

    while (_messageBuffer.contains('\n')) {
      int index = _messageBuffer.indexOf('\n');
      String message = _messageBuffer.substring(0, index).trim();
      _messageBuffer = _messageBuffer.substring(index + 1);

      // Handle Battery Status command
      if (message.startsWith("Battery:{") && message.endsWith("}")) {
        try {
          String content = message.substring(9, message.length - 1);
          List<String> parts = content.split(',');
          if (parts.length >= 2) {
            setState(() {
              _batteryLevel = int.tryParse(parts[0]) ?? 0;
              _isCharging = (parts[1].trim() == "1");
            });
          }
        } catch (e) {
          debugPrint("Error parsing battery data");
        }
      }
    }
  }

  void _disconnect() {
    _connection?.dispose();
    _connection = null;
    setState(() {
      _isConnected = false;
      _selectedDevice = null;
      _batteryLevel = 0;
      _isCharging = false;
    });
  }

  Future<void> _deleteRemote(int index) async {
    if (index < 0 || index >= _remotes.length) return;
    final String remoteName = _remotes[index].name;
    setState(() {
      _remotes.removeAt(index);
    });
    await _saveRemotes();
    _showStatus("Remote '$remoteName' deleted.");
  }

  void _showDeleteConfirmationDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Remote?"),
          content: Text("Are you sure you want to delete '${_remotes[index].name}'? This cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Delete"),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRemote(index);
              },
            ),
          ],
        );
      },
    );
  }

  void _renameRemote(int index) {
    TextEditingController renameController = TextEditingController(text: _remotes[index].name);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Rename Remote"),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(labelText: "New Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () {
                if (renameController.text.isNotEmpty) {
                  setState(() {
                    _remotes[index].name = renameController.text.trim();
                  });
                  _saveRemotes();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateSelectDeviceType() async {
    if (_connection == null) {
      _showError("Not connected. Please connect to a device first.");
      return;
    }
    final allNames = _remotes.map((r) => r.name.toLowerCase()).toList();
    final newRemote = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectDeviceTypePage(
          connection: _connection!,
          existingNames: allNames,
        ),
      ),
    );

    if (newRemote is RemoteControl) {
      if (!mounted) return;
      setState(() {
        _remotes.add(newRemote);
      });
      int newIndex = _remotes.length - 1;
      if (_connection == null || _broadcastStream == null) {
        _showError("Connection lost! Re-connect and tap remote to configure.");
        setState(() {
          _remotes.removeAt(newIndex);
        });
        return;
      }
      await _navigateToPage(newIndex, ControlMode.configure);
      if (mounted && newIndex < _remotes.length) {
        final finalRemote = _remotes[newIndex];
        if (finalRemote.name == newRemote.name && finalRemote.codes.isEmpty && finalRemote.deviceType != 'AC') {
          if (finalRemote.codes.isEmpty) {
            setState(() {
              _remotes.removeAt(newIndex);
            });
            _showStatus("Remote not saved (not configured).");
          }
        }
      }
    }
  }

  void _navigateToRemoteControlPage(int remoteIndex) {
    if (_connection == null || _broadcastStream == null) return;
    final remote = _remotes[remoteIndex];
    final bool isConfigured = remote.codes.isNotEmpty;
    final ControlMode initialMode = isConfigured ? ControlMode.ir : ControlMode.configure;
    _navigateToPage(remoteIndex, initialMode);
  }

  void _navigateToRemoteControlPageForConfig(int remoteIndex) {
    if (_connection == null || _broadcastStream == null) {
      _showError("Not connected. Please connect to a device first.");
      return;
    }
    _navigateToPage(remoteIndex, ControlMode.configure);
  }

  Future<void> _navigateToPage(int remoteIndex, ControlMode mode) async {
    if (remoteIndex < 0 || remoteIndex >= _remotes.length) {
      _showError("Error: Remote not found.");
      return;
    }
    if (_connection == null || _broadcastStream == null) {
      _showError("Not connected. Please connect to a device first.");
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RemoteControlPage(
          connection: _connection!,
          broadcastStream: _broadcastStream!,
          remote: _remotes[remoteIndex],
          remoteIndex: remoteIndex,
          onUpdateRemote: (updatedRemote) {
            bool isFirstSave = (remoteIndex < _remotes.length &&
                _remotes[remoteIndex].codes.isEmpty &&
                updatedRemote.codes.isNotEmpty);
            if (mounted) {
              setState(() {
                _remotes[remoteIndex] = updatedRemote;
              });
              _saveRemotes();
              if (isFirstSave) {
                _showStatus("'${updatedRemote.name}' saved!");
              }
            }
          },
          initialMode: mode,
        ),
      ),
    );
  }

  void _showRemoteOptionsSheet(int index) {
    final remote = _remotes[index];
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                title: Text(remote.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_remote),
                title: const Text('Configure'),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToRemoteControlPageForConfig(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.of(context).pop();
                  _renameRemote(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmationDialog(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Icon _getIconForDeviceType(String deviceType) {
    switch (deviceType) {
      case 'TV': return const Icon(Icons.tv);
      case 'AC': return const Icon(Icons.ac_unit);
      case 'FAN': return const Icon(Icons.air);
      case 'SPEAKER': return const Icon(Icons.speaker);
      case 'BOX': return const Icon(Icons.connected_tv);
      default: return const Icon(Icons.settings_remote);
    }
  }

  Future<void> _getPairedDevices() async {
    List<BluetoothDevice> devices = [];
    try {
      devices = await _bluetooth.getBondedDevices();
    } catch (e) {
      _showError("Error getting paired devices: $e");
    }
    if (!mounted) return;
    setState(() {
      _devicesList = devices;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(message)));
  }

  void _showStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnect();
    super.dispose();
  }

  // --- Battery Indicator Widget ---
  Widget _buildBatteryIndicator() {
    Color batteryColor = _isConnected
        ? (_isCharging ? Colors.green : Colors.black)
        : Colors.grey.withOpacity(0.5);

    double fillWidth = 18.0 * (_batteryLevel / 100);

    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Center(
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Body
            Container(
              width: 22,
              height: 12,
              decoration: BoxDecoration(
                border: Border.all(color: batteryColor, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Level
            if (_isConnected)
              Positioned(
                left: 2,
                child: Container(
                  width: fillWidth > 18 ? 18 : fillWidth,
                  height: 8,
                  decoration: BoxDecoration(
                    color: batteryColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            // Tip
            Positioned(
              right: -3,
              child: Container(
                width: 3,
                height: 6,
                decoration: BoxDecoration(
                  color: batteryColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(1),
                    bottomRight: Radius.circular(1),
                  ),
                ),
              ),
            ),
            // Charging Bolt
            if (_isConnected && _isCharging)
              const Positioned(
                left: 4,
                child: Icon(Icons.bolt, size: 12, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      return Scaffold(
        backgroundColor: Colors.blue[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: const Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 80,
                      color: Colors.blueAccent
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Bluetooth is Off",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "To configure and use your IR Remote, please enable Bluetooth on your device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5
                  ),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _enableBluetooth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)
                      ),
                    ),
                    child: const Text(
                        "TURN ON BLUETOOTH",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2
                        )
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IR Remote Configurator'),
        actions: [
          _buildBatteryIndicator(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButton<BluetoothDevice>(
                    isExpanded: true,
                    hint: const Text("Select Paired Device"),
                    value: _selectedDevice,
                    onChanged: _isConnected || _isConnecting
                        ? null
                        : (device) => setState(() => _selectedDevice = device),
                    items: _devicesList.map((device) => DropdownMenuItem(
                      value: device,
                      child: Text(device.name ?? "Unknown Device"),
                    )).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnecting
                      ? null
                      : (_isConnected
                      ? _disconnect
                      : (_selectedDevice != null ? _connect : null)),
                  child: _isConnecting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isConnected ? 'Disconnect' : 'Connect'),
                  style:ElevatedButton.styleFrom(
                    foregroundColor: _isConnected ? Colors.red : Colors.blue,
                    backgroundColor: _isConnected ? Colors.red[50] : Colors.blue[50],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _remotes.isEmpty
                ? const Center(child: Text("No remotes added yet.\nConnect to a device to add one.", textAlign: TextAlign.center))
                : ListView.builder(
              itemCount: _remotes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: _getIconForDeviceType(_remotes[index].deviceType),
                  title: Text(_remotes[index].name),
                  onTap: _isConnected ? () => _navigateToRemoteControlPage(index) : null,
                  onLongPress: () => _showRemoteOptionsSheet(index),
                  trailing: const Icon(Icons.arrow_forward_ios),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isConnected
          ? FloatingActionButton(
        onPressed: _navigateSelectDeviceType,
        child: const Icon(Icons.add),
        tooltip: 'Add New Remote',
      )
          : null,
    );
  }
}