// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import '../models/remote_control.dart';
// import 'remote_control_page.dart';
//
// class HomePage extends StatefulWidget {
//   final BluetoothConnection? connection;
//   final String deviceName;
//   final VoidCallback onDisconnect;
//   final List<RemoteControl> remotes;
//   final Function(RemoteControl) onAddRemote;
//   final Function(int) onDeleteRemote;
//   final Function(int, RemoteControl) onUpdateRemote;
//
//   const HomePage({
//     super.key,
//     required this.connection,
//     required this.deviceName,
//     required this.onDisconnect,
//     required this.remotes,
//     required this.onAddRemote,
//     required this.onDeleteRemote,
//     required this.onUpdateRemote,
//   });
//
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   Stream<Uint8List>? _broadcastStream;
//   int _batteryLevel = 0;
//   bool _isCharging = false;
//   bool _hasBatteryData = false;
//
//   @override
//   void initState() {
//     super.initState();
//     if (widget.connection != null && widget.connection!.isConnected) {
//       // Create a broadcast stream so we can listen here AND in the remote page
//       _broadcastStream = widget.connection!.input!.asBroadcastStream();
//       _broadcastStream!.listen(_onDataReceived);
//     }
//   }
//
//   void _onDataReceived(Uint8List data) {
//     String message = utf8.decode(data).trim();
//     if (message.startsWith("Battery:{") && message.endsWith("}")) {
//       try {
//         String content = message.substring(9, message.length - 1);
//         List<String> parts = content.split(',');
//         if (parts.length >= 2) {
//           int level = int.tryParse(parts[0]) ?? 0;
//           int charging = int.tryParse(parts[1]) ?? 0;
//           if (mounted) {
//             setState(() {
//               _batteryLevel = level.clamp(0, 100);
//               _isCharging = (charging == 1);
//               _hasBatteryData = true;
//             });
//           }
//         }
//       } catch (e) {
//         // Suppress parsing errors
//       }
//     }
//   }
//
//   void _showConnectionErrorPopup() {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Connection Error"),
//         content: const Text("The ESP32 device is not connected. Please connect to a device first."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text("OK"),
//           )
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     bool isConnected = widget.connection != null && widget.connection!.isConnected;
//
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         title: const Text("IR Remote Configurator", style: TextStyle(color: Colors.black)),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           _buildBatteryWidget(isConnected),
//           const SizedBox(width: 16),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Connection Status Bar
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             color: Colors.white,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.bluetooth, size: 16, color: isConnected ? Colors.blue : Colors.grey),
//                     const SizedBox(width: 8),
//                     Text(
//                       isConnected ? widget.deviceName : "Disconnected",
//                       style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
//                     ),
//                   ],
//                 ),
//                 if (isConnected)
//                   TextButton(
//                     onPressed: widget.onDisconnect,
//                     style: TextButton.styleFrom(
//                       backgroundColor: Colors.red[50],
//                       foregroundColor: Colors.red,
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                       minimumSize: Size.zero,
//                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                     ),
//                     child: const Text("Disconnect", style: TextStyle(fontSize: 12)),
//                   ),
//               ],
//             ),
//           ),
//           const Divider(height: 1),
//
//           // Remote List
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: widget.remotes.length,
//               itemBuilder: (context, index) {
//                 final remote = widget.remotes[index];
//                 IconData icon = Icons.settings_remote;
//                 if (remote.deviceType == 'AC') icon = Icons.ac_unit;
//                 else if (remote.deviceType == 'TV') icon = Icons.tv;
//                 else if (remote.deviceType == 'Fan') icon = Icons.wind_power;
//
//                 return Card(
//                   elevation: 0,
//                   color: Colors.transparent,
//                   margin: const EdgeInsets.only(bottom: 8),
//                   child: InkWell(
//                     onTap: () {
//                       if (!isConnected) {
//                         _showConnectionErrorPopup();
//                         return;
//                       }
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => RemoteControlPage(
//                             connection: widget.connection!,
//                             broadcastStream: _broadcastStream!,
//                             remote: remote,
//                             remoteIndex: index,
//                             initialMode: ControlMode.ir,
//                             onUpdateRemote: (updated) => widget.onUpdateRemote(index, updated),
//                             // FIXED: Passed required battery arguments
//                             initialBatteryLevel: _batteryLevel,
//                             initialChargingState: _isCharging,
//                           ),
//                         ),
//                       );
//                     },
//                     child: Row(
//                       children: [
//                         Icon(icon, color: Colors.grey[600], size: 20),
//                         const SizedBox(width: 16),
//                         Expanded(child: Text(remote.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
//                         IconButton(
//                           icon: const Icon(Icons.settings, color: Colors.grey),
//                           onPressed: () {
//                             if (!isConnected) {
//                               _showConnectionErrorPopup();
//                               return;
//                             }
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => RemoteControlPage(
//                                   connection: widget.connection!,
//                                   broadcastStream: _broadcastStream!,
//                                   remote: remote,
//                                   remoteIndex: index,
//                                   initialMode: ControlMode.configure,
//                                   onUpdateRemote: (updated) => widget.onUpdateRemote(index, updated),
//                                   // FIXED: Passed required battery arguments
//                                   initialBatteryLevel: _batteryLevel,
//                                   initialChargingState: _isCharging,
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         const Icon(Icons.chevron_right, color: Colors.grey),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           // Add Remote Logic
//         },
//         backgroundColor: Colors.deepPurple[100],
//         child: const Icon(Icons.add, color: Colors.deepPurple),
//       ),
//     );
//   }
//
//   Widget _buildBatteryWidget(bool isConnected) {
//     // 1. Disconnected
//     if (!isConnected) {
//       return Opacity(
//         opacity: 0.5,
//         child: Row(
//           children: [
//             Stack(alignment: Alignment.centerLeft, children: [
//               Container(width: 32, height: 16, decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 2), borderRadius: BorderRadius.circular(4))),
//             ]),
//             Container(width: 3, height: 8, decoration: const BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.only(topRight: Radius.circular(2), bottomRight: Radius.circular(2)))),
//           ],
//         ),
//       );
//     }
//
//     // 2. Connected
//     Color mainColor = _isCharging ? Colors.green : Colors.black;
//     double fillWidth = _hasBatteryData ? (24.0 * (_batteryLevel / 100)) : 0.0;
//
//     return Row(
//       children: [
//         if (_isCharging) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.bolt, size: 18, color: Colors.green)),
//         Stack(alignment: Alignment.centerLeft, children: [
//           Container(width: 32, height: 16, decoration: BoxDecoration(border: Border.all(color: mainColor, width: 2), borderRadius: BorderRadius.circular(4))),
//           Container(margin: const EdgeInsets.only(left: 2), width: fillWidth, height: 12, decoration: BoxDecoration(color: mainColor, borderRadius: BorderRadius.circular(1))),
//         ]),
//         Container(width: 3, height: 8, decoration: BoxDecoration(color: mainColor, borderRadius: const BorderRadius.only(topRight: Radius.circular(2), bottomRight: Radius.circular(2)))),
//       ],
//     );
//   }
// }