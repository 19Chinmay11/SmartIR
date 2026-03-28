import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/remote_control.dart';
import '../utils/remote_templates.dart';

enum ControlMode { configure, ir }

enum ConfigStep {
  idle,
  waitingForFirstPress,
  waitingForSecondPress,
  waitingForThirdPress,
  waitingForData,
}

enum AcScanState { scanning, success, error }

class RemoteControlPage extends StatefulWidget {
  final BluetoothConnection connection;
  final Stream<Uint8List> broadcastStream;
  final RemoteControl remote;
  final int remoteIndex;
  final Function(RemoteControl) onUpdateRemote;
  final ControlMode initialMode;

  const RemoteControlPage({
    super.key,
    required this.connection,
    required this.broadcastStream,
    required this.remote,
    required this.remoteIndex,
    required this.onUpdateRemote,
    required this.initialMode,
  });

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> with SingleTickerProviderStateMixin {
  late ControlMode _currentMode;
  StreamSubscription<Uint8List>? _inputSubscription;
  String _messageBuffer = '';
  String _statusText = "Initializing...";

  // --- AC State ---
  int _acFailureCount = 0;
  bool _isAcProtocolFetched = false;
  AcScanState _acScanState = AcScanState.scanning;

  // --- Animation ---
  late AnimationController _pulseController;
  double _circleSize = 250.0;
  double _circleOpacity = 0.2;
  Color _circleColor = Colors.blue;

  // --- AC Variables ---
  bool _acPower = false;
  int _acMode = 1;
  int _acTemp = 24;
  int _acFan = 0;
  int _acSwingV = 0;
  int? _acProtocol;

  // --- Standard Config State ---
  ConfigStep _configStep = ConfigStep.idle;
  String? _configuringButtonName;
  String? _configuringButtonCode;

  // UI Flags
  bool _configError = false;
  bool _configSuccess = false;
  // New: Flag to block input briefly during result animation
  bool _isBlockingUI = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;

    _setupInitialStatus();

    _inputSubscription = widget.broadcastStream.listen(_onDataReceived, onDone: () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Device Disconnected"), backgroundColor: Colors.red),
        );
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Fast pulse
    )..repeat(reverse: true);

    if (widget.remote.deviceType == 'AC') {
      _loadAcState();
    }

    if (_currentMode == ControlMode.configure) {
      _sendEnableReceiveCommand();
    } else if (_currentMode == ControlMode.ir) {
      if (widget.remote.deviceType == 'AC' && widget.remote.codes.containsKey('AC_CONFIG')) {
        _parseAcConfig(widget.remote.codes['AC_CONFIG']!);
      }
      _sendEnableTransmitCommand();
    }
  }

  void _setupInitialStatus() {
    if (_currentMode == ControlMode.configure && widget.remote.deviceType == 'AC') {
      _statusText = "Point Remote at ESP32\nPress Power Button";
      _acScanState = AcScanState.scanning;
      _circleColor = Colors.blue;
      _circleOpacity = 0.2;
    } else if (_currentMode == ControlMode.configure) {
      _statusText = "Select a button to configure.";
    } else {
      _statusText = "Ready";
    }
  }

  Future<void> _loadAcState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "ac_state_${widget.remote.name}";
    setState(() {
      _acPower = prefs.getBool('${key}_power') ?? false;
      _acMode = prefs.getInt('${key}_mode') ?? 1;
      _acTemp = prefs.getInt('${key}_temp') ?? 24;
      _acFan = prefs.getInt('${key}_fan') ?? 0;
      _acSwingV = prefs.getInt('${key}_swing') ?? 0;
    });
  }

  Future<void> _saveAcState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "ac_state_${widget.remote.name}";
    await prefs.setBool('${key}_power', _acPower);
    await prefs.setInt('${key}_mode', _acMode);
    await prefs.setInt('${key}_temp', _acTemp);
    await prefs.setInt('${key}_fan', _acFan);
    await prefs.setInt('${key}_swing', _acSwingV);
  }

  void _parseAcConfig(String configStr) {
    try {
      _acProtocol = int.parse(configStr);
    } catch (e) {
      print("Error parsing saved AC config: $e");
    }
  }

  Future<void> _sendEnableReceiveCommand() async {
    try {
      final formattedName = widget.remote.name.replaceAll(' ', '_');
      String commandPrefix = (widget.remote.deviceType == 'AC') ? "AC_conf_EN" : "IRrecEN";
      String command = "$commandPrefix:$formattedName\n";
      await _sendRaw(command);
    } catch (e) {
      _handleError("Error enabling config", e);
    }
  }

  Future<void> _sendDisableReceiveCommand() async {
    try {
      final formattedName = widget.remote.name.replaceAll(' ', '_');
      String commandPrefix = (widget.remote.deviceType == 'AC') ? "AC_conf_DN" : "IRrecDN";
      String command = "$commandPrefix:$formattedName\n";
      await _sendRaw(command);
    } catch (e) {
      print("Error sending disable command: $e");
    }
  }

  Future<void> _sendEnableTransmitCommand() async {
    try {
      final formattedName = widget.remote.name.replaceAll(' ', '_');
      String commandPrefix = (widget.remote.deviceType == 'AC') ? "AC_IR_EN" : "IRtranEN";
      String command = "$commandPrefix:$formattedName\n";
      await _sendRaw(command);
    } catch (e) {
      _handleError("Error enabling transmit", e);
    }
  }

  Future<void> _sendDisableTransmitCommand() async {
    try {
      final formattedName = widget.remote.name.replaceAll(' ', '_');
      String commandPrefix = (widget.remote.deviceType == 'AC') ? "AC_IR_DN" : "IRtranDN";
      String command = "$commandPrefix:$formattedName\n";
      await _sendRaw(command);
    } catch (e) {
      print("Error sending IRtranDN: $e");
    }
  }

  Future<void> _sendRaw(String command) async {
    if (widget.connection.isConnected) {
      widget.connection.output.add(Uint8List.fromList(utf8.encode(command)));
      await widget.connection.output.allSent;
    }
  }

  void _handleError(String prefix, Object e) {
    if (mounted) {
      setState(() {
        _statusText = "$prefix: $e";
      });
    }
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _pulseController.dispose();
    if (_currentMode == ControlMode.configure) {
      _sendDisableReceiveCommand();
    } else if (_currentMode == ControlMode.ir) {
      _sendDisableTransmitCommand();
    }
    super.dispose();
  }

  void _onDataReceived(Uint8List data) {
    String dataString = utf8.decode(data);
    _messageBuffer += dataString;

    while (_messageBuffer.contains('\n')) {
      int index = _messageBuffer.indexOf('\n');
      String message = _messageBuffer.substring(0, index).trim();
      _messageBuffer = _messageBuffer.substring(index + 1);

      // --- 1. AC CONFIG LOGIC ---
      if (widget.remote.deviceType == 'AC' && _currentMode == ControlMode.configure) {
        if (message.startsWith("AC:{") && message.endsWith("}")) {
          try {
            String content = message.substring(4, message.length - 1);
            List<String> parts = content.split(',');

            if (parts.length >= 2) {
              int protocol = int.tryParse(parts[0]) ?? -1;
              String brandName = parts[1].replaceAll('_', ' ');

              if (protocol > 0) {
                _pulseController.stop();
                setState(() {
                  _isAcProtocolFetched = true;
                  _acScanState = AcScanState.success;
                  _statusText = "Success! $brandName";
                  _acProtocol = protocol;
                  widget.remote.codes['AC_CONFIG'] = "$protocol";
                  _circleColor = Colors.blue;
                  _circleSize = MediaQuery.of(context).size.height * 3.0;
                  _circleOpacity = 0.0;
                });

                widget.onUpdateRemote(widget.remote);

                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) _switchToIrMode();
                });
              } else {
                setState(() {
                  _acFailureCount++;
                  _acScanState = AcScanState.error;
                  _circleColor = Colors.red;
                });

                if (_acFailureCount == 1) {
                  setState(() => _statusText = "Unable to detect AC signals.\nPlease try again.");
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _acScanState == AcScanState.error) {
                      setState(() {
                        _acScanState = AcScanState.scanning;
                        _statusText = "Press Power Button again...";
                        _circleColor = Colors.blue;
                        _circleOpacity = 0.2;
                      });
                    }
                  });
                } else {
                  setState(() => _statusText = "Failed to decode AC protocol.");
                  _showAcFailureDialog();
                }
              }
            }
          } catch (e) {
            print("Error parsing AC packet: $e");
          }
          return;
        }
      }

      // --- 2. STANDARD CONFIG LOGIC ---
      if (widget.remote.deviceType != 'AC') {

        if (_configuringButtonCode == null) {
          continue;
        }

        // SUCCESS: DATA RECEPTION
        if (_configStep == ConfigStep.waitingForData) {
          String expectedPrefix = "$_configuringButtonCode:{";
          if (message.startsWith(expectedPrefix) && message.endsWith("}")) {
            String content = message.substring(expectedPrefix.length, message.length - 1);
            int lastCommaIndex = content.lastIndexOf(',');
            if (lastCommaIndex != -1) {
              String potentialFlag = content.substring(lastCommaIndex + 1).trim();
              if (potentialFlag == "0" || potentialFlag == "1") {
                content = content.substring(0, lastCommaIndex);
              }
            }

            String buttonName = _configuringButtonName!;
            setState(() {
              widget.remote.codes[buttonName] = content;
              _statusText = "Button configured successfully.\nSelect another button to continue.";
              _configStep = ConfigStep.idle;
              _configSuccess = true; // Green
              _configError = false;
              _isBlockingUI = true; // Freeze briefly to show green
            });
            widget.onUpdateRemote(widget.remote);

            // Unfreeze and reset after 1s
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                setState(() {
                  _isBlockingUI = false;
                  _configSuccess = false;
                  _configuringButtonName = null;
                  _configuringButtonCode = null;
                  _statusText = "Select a button to configure.";
                });
              }
            });
            continue;
          }
        }

        // HANDSHAKE LOGIC
        if (message == "IR_rec_1:Pending") {
          setState(() {
            _configStep = ConfigStep.waitingForSecondPress;
            _statusText = "Signal received. Press button again to verify.";
            _configError = false;
          });
        }
        else if (message == "IR_rec_2:Success") {
          setState(() {
            _configStep = ConfigStep.waitingForData;
            _statusText = "Verified! Processing data...";
          });
        }
        else if (message == "IR_rec_2:Failed") {
          setState(() {
            _configStep = ConfigStep.waitingForThirdPress;
            _statusText = "Verification failed. Try again.";
            _configError = true; // Red pulse
          });
        }
        else if (message == "IR_rec_3:Success") {
          setState(() {
            _configStep = ConfigStep.waitingForData;
            _statusText = "Verified! Processing data...";
            _configError = false;
          });
        }

        // --- FAILURE LOGIC (FIXED) ---
        else if (message == "IR_rec_3:Failed") {
          setState(() {
            _configStep = ConfigStep.idle; // Reset logic state
            _statusText = "Error to configure the btn try again";
            _configError = true; // Turn Red
            _isBlockingUI = true; // Block clicks briefly to show error
          });

          // Clear Error State after 1.5s and Deselect
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _isBlockingUI = false; // Unlock
                _configError = false;
                _configuringButtonName = null; // DESELECT BUTTON HERE
                _configuringButtonCode = null;
                _statusText = "Select a button to configure.";
              });
            }
          });
        }
      }
    }
  }

  void _switchToIrMode() {
    _sendDisableReceiveCommand().then((_) {
      if (!mounted) return;
      setState(() {
        _currentMode = ControlMode.ir;
        _statusText = "AC Remote Ready";
      });
      _sendEnableTransmitCommand();
    });
  }

  void _showAcFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Failed to Fetch"),
        content: const Text("Unable to decode AC protocol.\nPlease try again later."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleButtonPress(String buttonName) async {
    // Prevent clicks if we are showing a Success/Error animation
    if (_isBlockingUI) return;

    final buttonData = RemoteTemplates.getButtonData(buttonName);
    if (buttonData == null) return;

    final remoteId = widget.remoteIndex;
    final codeToSend = buttonData.code;

    // --- IR MODE LOGIC ---
    if (_currentMode == ControlMode.ir) {
      if (widget.remote.deviceType == 'AC') {
        if (_acProtocol == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AC not configured! Go to Config Mode.")));
          return;
        }
        // (AC Logic same as before)
        setState(() {
          if (buttonName == 'power_on') _acPower = true;
          else if (buttonName == 'power_off') _acPower = false;
          else if (buttonName == 'power') _acPower = !_acPower;
          else if (buttonName.startsWith('temp_')) {
            if (buttonName == 'temp_up') _acTemp = (_acTemp < 30) ? _acTemp + 1 : 30;
            else if (buttonName == 'temp_down') _acTemp = (_acTemp > 16) ? _acTemp - 1 : 16;
            else {
              int? t = int.tryParse(buttonName.substring(5));
              if (t != null) _acTemp = t;
            }
          }
          else if (buttonName == 'mode') _acMode = (_acMode + 1) % 5;
          else if (buttonName == 'fan_auto') _acFan = 0;
          else if (buttonName == 'fan_low') _acFan = 2;
          else if (buttonName == 'fan_med') _acFan = 3;
          else if (buttonName == 'fan_high') _acFan = 5;
          else if (buttonName == 'speed') _acFan = (_acFan + 1) % 7;
          else if (buttonName == 'swing') _acSwingV = (_acSwingV + 1) % 7;
        });
        _saveAcState();
        int pwr = _acPower ? 1 : 0;
        String acPacket = "AC:{$_acProtocol,$pwr,$_acMode,$_acTemp,$_acSwingV,$_acFan}\n";
        await _sendRaw(acPacket);
        return;
      }

      var configuredData = widget.remote.codes[buttonName];
      if (configuredData != null) {
        configuredData = configuredData.trim();
        if (configuredData.startsWith("{")) configuredData = configuredData.substring(1, configuredData.length - 1);
        String packet = "$codeToSend:{$configuredData}\n";
        await _sendRaw(packet);
        setState(() => _statusText = "Sent '${buttonData.label}' command.");
      }
      return;
    }

    // --- CONFIG MODE LOGIC ---
    if (_currentMode == ControlMode.configure && widget.remote.deviceType != 'AC') {
      // Don't interrupt existing config
      if (_configStep != ConfigStep.idle && _configuringButtonName != buttonName) {
        return;
      }

      setState(() {
        _configuringButtonName = buttonName;
        _configuringButtonCode = codeToSend;
        _configStep = ConfigStep.waitingForFirstPress;
        _statusText = "Press '${buttonData.label}' on physical remote...";
        _configError = false;
        _configSuccess = false;
      });

      await _sendRaw("$remoteId:$codeToSend\n");
    }
  }

  void _showConfiguredDialog(String buttonName) { }

  String _getModeTitle() {
    if (widget.remote.deviceType == 'AC' && _currentMode == ControlMode.configure) return "";
    return _currentMode == ControlMode.configure ? "(Configure Mode)" : "(IR Mode)";
  }

  ({bool isConfigured, bool isEnabled}) _getButtonState(String buttonName) {
    if (widget.remote.deviceType == 'AC') {
      if (_currentMode == ControlMode.configure) return (isConfigured: true, isEnabled: true);
      if (!_acPower && !(buttonName == 'power' || buttonName == 'power_on' || buttonName == 'power_off')) {
        return (isConfigured: true, isEnabled: false);
      }
      return (isConfigured: true, isEnabled: true);
    }
    bool isConfigured = widget.remote.codes.containsKey(buttonName);
    bool isEnabled = _currentMode == ControlMode.configure || isConfigured;
    return (isConfigured: isConfigured, isEnabled: isEnabled);
  }

  // ... (Helpers like getModeName, getFanName, getSwingName etc. same as before) ...
  String _getModeName(int m) {
    switch(m) { case 0: return "Auto"; case 1: return "Cool"; case 2: return "Heat"; case 3: return "Dry"; case 4: return "Fan"; default: return "Auto"; }
  }
  String _getFanName(int f) {
    switch(f) { case 0: return "Auto"; case 1: return "Min"; case 2: return "Low"; case 3: return "Med"; case 4: return "High"; case 5: return "Max"; case 6: return "MedHi"; default: return "Auto"; }
  }
  String _getSwingName(int s) {
    switch(s) { case 0: return "Auto"; case 1: return "Highest"; case 2: return "High"; case 3: return "Middle"; case 4: return "Low"; case 5: return "Lowest"; case 6: return "UpperMid"; default: return "Auto"; }
  }

  @override
  Widget build(BuildContext context) {
    // ... (AC Config Screen same as before) ...
    if (widget.remote.deviceType == 'AC' && _currentMode == ControlMode.configure) {
      return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(title: Text("Configuring ${widget.remote.name}")),
          body: Stack(children: [
            Center(child: AnimatedContainer(duration: const Duration(milliseconds: 800), curve: Curves.easeOut, width: _circleSize, height: _circleSize, decoration: BoxDecoration(shape: BoxShape.circle, color: _circleColor.withOpacity(_circleOpacity)))),
            Center(child: Text(_statusText, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _configError ? Colors.red : Colors.black)))
          ])
      );
    }

    List<String> acButtons = RemoteTemplates.getAcLayoutButtons(widget.remote.deviceType);
    List<String> speakerButtons = RemoteTemplates.getSpeakerGridButtons(widget.remote.deviceType);
    List<String> simpleGridButtons = RemoteTemplates.getSimpleGridButtons(widget.remote.deviceType);
    bool isAcLayout = acButtons.isNotEmpty;
    bool isSpeakerLayout = speakerButtons.isNotEmpty;
    bool isSimpleLayout = simpleGridButtons.isNotEmpty;

    String? currentConfigBtn = (_configStep != ConfigStep.idle || _configSuccess || _configError) ? _configuringButtonName : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.remote.name),
            Text(_getModeTitle(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: ListView(
        children: [
          if (isAcLayout)
            Padding(padding: const EdgeInsets.all(16.0), child: _buildAcScreen())
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _configError ? Colors.red : (_configSuccess ? Colors.green : Colors.black),
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (isAcLayout) _buildAcLayout(context, currentConfigBtn)
          else if (isSpeakerLayout) _buildSpeakerLayout(context, speakerButtons, currentConfigBtn)
          else if (isSimpleLayout) _buildSimpleGridSection(context, simpleGridButtons, currentConfigBtn)
            else _buildTvLayout(context, currentConfigBtn),
        ],
      ),
    );
  }

  // ... (Layout methods same as before) ...

  Widget _buildGridButton(BuildContext context, String buttonName, String? currentConfigBtn, {bool isWide = false}) {
    final buttonData = RemoteTemplates.getButtonData(buttonName);
    if (buttonData == null) return const Card(child: Center(child: Text("?")));

    final state = _getButtonState(buttonName);

    bool isScanning = (_configuringButtonName == buttonName);

    Color contentColor = (state.isConfigured || _currentMode == ControlMode.configure) ? Colors.black : Colors.grey[400]!;
    if (_currentMode == ControlMode.configure && state.isConfigured) contentColor = Theme.of(context).primaryColor;
    if (isScanning) contentColor = Colors.black; // Keep icon visible

    double opacity = state.isEnabled ? 1.0 : 0.3;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        List<BoxShadow> shadows = [];
        Color borderColor = Colors.grey[200]!;

        if (isScanning) {
          // ANIMATED SCANNING
          double spread = 2 + (_pulseController.value * 6);
          double blur = 4 + (_pulseController.value * 6);
          Color glowColor = Colors.blue; // Default Scan

          if (_configSuccess) glowColor = Colors.green;
          else if (_configError) glowColor = Colors.red;
          else if (_configStep == ConfigStep.waitingForSecondPress || _configStep == ConfigStep.waitingForThirdPress) glowColor = Colors.orange;

          shadows.add(BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: blur, spreadRadius: spread));
          borderColor = glowColor;
        }

        return Opacity(
          opacity: opacity,
          child: SizedBox(
            width: isWide ? null : 80,
            height: 72,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: isScanning ? 2 : 1),
                boxShadow: shadows,
              ),
              child: InkWell(
                onTap: state.isEnabled ? () => _handleButtonPress(buttonName) : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (buttonData.icon != null)
                        Icon(buttonData.icon, size: 28, color: contentColor),
                      const SizedBox(height: 4),
                      Text(
                        buttonData.label,
                        style: TextStyle(fontSize: 12, color: contentColor),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildAcLayout(BuildContext context, String? currentConfigBtn) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildGridButton(context, 'power', currentConfigBtn), _buildGridButton(context, 'mode', currentConfigBtn)]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildGridButton(context, 'speed', currentConfigBtn), _buildGridButton(context, 'swing', currentConfigBtn)]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
            _buildGridButton(context, 'temp_down', currentConfigBtn),
            const Text("TEMP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            _buildGridButton(context, 'temp_up', currentConfigBtn),
          ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcScreen() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _acPower ? Colors.blue[50] : Colors.grey[300],
        border: Border.all(color: _acPower ? Colors.blue[200]! : Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(Icons.power_settings_new, color: _acPower ? Colors.blue : Colors.grey[600]),
            Text(_getModeName(_acMode).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _acPower ? Colors.black : Colors.grey)),
            Icon(Icons.air, color: (_acPower && _acFan > 0) ? Colors.blue : Colors.grey),
          ],
          ),
          const SizedBox(height: 10),
          Text("$_acTemp°C", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _acPower ? Colors.black87 : Colors.grey[600])),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Fan: ${_getFanName(_acFan)}", style: TextStyle(color: _acPower ? Colors.black : Colors.grey)),
            Text("Swing: ${_getSwingName(_acSwingV)}", style: TextStyle(color: _acPower ? Colors.black : Colors.grey)),
          ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerLayout(BuildContext context, List<String> buttons, String? currentConfigBtn) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: buttons.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => _buildGridButton(context, buttons[index], currentConfigBtn, isWide: true),
    );
  }

  Widget _buildSimpleGridSection(BuildContext context, List<String> buttons, String? currentConfigBtn) {
    if (widget.remote.deviceType == 'FAN') {
      return Padding(
        // This 16.0 matches the padding used in your GridView.builder
        padding: const EdgeInsets.symmetric(horizontal: 38.0, vertical: 22.0),
        child: Column(
          children: [
            // Row 1: Power & Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGridButton(context, 'power', currentConfigBtn),
                _buildGridButton(context, 'timer', currentConfigBtn),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Speed + & Speed -
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGridButton(context, 'speed_inc', currentConfigBtn),
                _buildGridButton(context, 'speed_dec', currentConfigBtn),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Sleep & Light
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGridButton(context, 'sleep', currentConfigBtn),
                _buildGridButton(context, 'light', currentConfigBtn),
              ],
            ),
            const SizedBox(height: 20), // Spacer before the numbers

            // Row 4: 1, 2, 3 (Manually aligned to match the top rows)
            Text("Speed Controllers", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGridButton(context, 'num_1', currentConfigBtn),
                _buildGridButton(context, 'num_2', currentConfigBtn),
                _buildGridButton(context, 'num_3', currentConfigBtn),
              ],
            ),
            const SizedBox(height: 12),

            // Row 5: 4, 5, 6
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGridButton(context, 'num_4', currentConfigBtn),
                _buildGridButton(context, 'num_5', currentConfigBtn),
                _buildGridButton(context, 'num_6', currentConfigBtn),
              ],
            ),
          ],
        ),
      );
    }
    // Fallback for other "Simple Grid" devices
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8
      ),
      itemCount: buttons.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => _buildGridButton(context, buttons[index], currentConfigBtn),
    );
  }
  Widget _buildTvLayout(BuildContext context, String? currentConfigBtn) {
    return Column(children: [_buildTopGridSection(context, currentConfigBtn), _buildControlPadSection(context, currentConfigBtn), _buildNumpadSection(context, currentConfigBtn)]);
  }

  Widget _buildTopGridSection(BuildContext context, String? currentConfigBtn) {
    final topButtons = RemoteTemplates.getTopGridButtons(widget.remote.deviceType);
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: topButtons.length, itemBuilder: (context, index) => _buildGridButton(context, topButtons[index], currentConfigBtn));
  }

  Widget _buildControlPadSection(BuildContext context, String? currentConfigBtn) {
    final controlButtons = RemoteTemplates.getControlPadButtons(widget.remote.deviceType);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // --- 1. NAVIGATION D-PAD (TOP CENTER) ---
          if (controlButtons.contains('up'))
            Column(
              children: [
                _buildGridButton(context, 'up', currentConfigBtn),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGridButton(context, 'left', currentConfigBtn),
                    const SizedBox(width: 8),
                    _buildGridButton(context, 'ok', currentConfigBtn),
                    const SizedBox(width: 8),
                    _buildGridButton(context, 'right', currentConfigBtn),
                  ],
                ),
                const SizedBox(height: 8),
                _buildGridButton(context, 'down', currentConfigBtn),
              ],
            ),

          const SizedBox(height: 30), // Space between D-Pad and Bottom Controls


          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controlButtons.contains('vol_up'))
                  Column(
                    children: [
                      _buildGridButton(context, 'vol_up', currentConfigBtn),
                      const SizedBox(height: 12),
                      _buildGridButton(context, 'vol_down', currentConfigBtn),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("VOL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                if (controlButtons.contains('ch_up'))
                  Column(
                    children: [
                      _buildGridButton(context, 'ch_up', currentConfigBtn),
                      const SizedBox(height: 12),
                      _buildGridButton(context, 'ch_down', currentConfigBtn),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("CH", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadSection(BuildContext context, String? currentConfigBtn) {
    final numpadButtons = RemoteTemplates.getNumpadButtons(widget.remote.deviceType);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildNumpadButton(context, 'num_1', currentConfigBtn), _buildNumpadButton(context, 'num_2', currentConfigBtn), _buildNumpadButton(context, 'num_3', currentConfigBtn)]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildNumpadButton(context, 'num_4', currentConfigBtn), _buildNumpadButton(context, 'num_5', currentConfigBtn), _buildNumpadButton(context, 'num_6', currentConfigBtn)]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildNumpadButton(context, 'num_7', currentConfigBtn), _buildNumpadButton(context, 'num_8', currentConfigBtn), _buildNumpadButton(context, 'num_9', currentConfigBtn)]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [const SizedBox(width: 80), _buildNumpadButton(context, 'num_0', currentConfigBtn), const SizedBox(width: 80)]),
      const SizedBox(height: 20),
    ]));
  }

  Widget _buildNumpadButton(BuildContext context, String buttonName, String? currentConfigBtn) {
    return _buildGridButton(context, buttonName, currentConfigBtn);
  }
}