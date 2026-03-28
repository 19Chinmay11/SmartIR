import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Bluetooth Chat',
      home: BluetoothChatPage(),
    );
  }
}

// Helper class to represent a chat message
class _Message {
  final int who; // 0 for me, 1 for them
  final String text;

  _Message(this.who, this.text);
}

class BluetoothChatPage extends StatefulWidget {
  const BluetoothChatPage({super.key});

  @override
  State<BluetoothChatPage> createState() => _BluetoothChatPageState();
}

class _BluetoothChatPageState extends State<BluetoothChatPage> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isConnecting = false;

  // State for the chat
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_Message> _messages = [];
  StreamSubscription<Uint8List>? _inputSubscription;
  String _messageBuffer = '';

  @override
  void initState() {
    super.initState();
    _getPairedDevices();
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

  void _connect() async {
    if (_selectedDevice == null) {
      _showError("No device selected.");
      return;
    }
    setState(() { _isConnecting = true; });

    try {
      _connection = await BluetoothConnection.toAddress(_selectedDevice!.address);
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connected to ${_selectedDevice!.name}")));

      // Start listening to the input stream
      _inputSubscription = _connection!.input!.listen(_onDataReceived);

    } catch (e) {
      _showError("Failed to connect: $e");
      setState(() { _isConnecting = false; });
    }
  }

  void _disconnect() {
    // Cancel the stream subscription and dispose the connection
    _inputSubscription?.cancel();
    _connection?.dispose();
    setState(() { _isConnected = false; });
  }

  void _onDataReceived(Uint8List data) {
    // Decode the incoming data and add it to the buffer
    String dataString = utf8.decode(data);
    _messageBuffer += dataString;

    // Process the buffer until all complete messages (ending with '\n') are handled
    while (_messageBuffer.contains('\n')) {
      int index = _messageBuffer.indexOf('\n');
      String message = _messageBuffer.substring(0, index).trim();
      _messageBuffer = _messageBuffer.substring(index + 1);

      if (message.isNotEmpty) {
        setState(() {
          _messages.add(_Message(1, message)); // 1 for "them"
        });
        // Auto-scroll to the bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

  void _sendMessage() async {
    if (_connection == null || !_isConnected) {
      _showError("Not connected to any device.");
      return;
    }
    String message = _textController.text.trim();
    if (message.isEmpty) return;

    try {
      // Add the newline character, which we use as a message delimiter
      _connection!.output.add(Uint8List.fromList(utf8.encode("$message\n")));
      await _connection!.output.allSent;

      setState(() {
        _messages.add(_Message(0, message)); // 0 for "me"
      });
      _textController.clear();
      // Auto-scroll to the bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      _showError("Error sending message: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
            'Bluetooth Chat App',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        elevation: 4.0,
      ),
      body: Column(
        children: [
          // Connection UI
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
                    onChanged: (device) => setState(() => _selectedDevice = device), //setState re-build the UI
                    items: _devicesList.map((device) {
                      return DropdownMenuItem(
                        value: device,
                        child: Text(device.name ?? "Unknown Device"), // ?? checkes where the passed argument is null or not if it null then it returns unkown else it return actual value inside device.name
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnecting ? null : (_isConnected ? _disconnect : _connect),
                  child: _isConnecting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) // if _isConnecting returns true
                      : Text(_isConnected ? 'Disconnect' : 'Connect'),// if _isConnecting returns false
                ),
              ],
            ),
          ),
          const Divider(),
          // Chat View
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Align(
                    alignment: message.who == 0 ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: message.who == 0 ? Colors.blue[200] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(message.text),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          // Input Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Enter message...',
                      border: OutlineInputBorder(),
                    ),
                    enabled: _isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isConnected ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}