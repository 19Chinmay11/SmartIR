import 'package:flutter/material.dart';

class RemoteButtonData {
  final String label;
  final String code;
  final IconData? icon;

  RemoteButtonData({required this.label, required this.code, this.icon});
}

class RemoteTemplates {
  // --- MASTER LIST OF ALL BUTTONS ---
  static final Map<String, RemoteButtonData> _buttonMap = {



    // Standard
    'power': RemoteButtonData(label: 'Power', code: 'PWR', icon: Icons.power_settings_new),
    'source': RemoteButtonData(label: 'Source', code: 'SRC', icon: Icons.input),
    'mute': RemoteButtonData(label: 'Mute', code: 'MUT', icon: Icons.volume_off),

    // Volume
    'vol_up': RemoteButtonData(label: 'Vol +', code: 'VUP', icon: Icons.volume_up),
    'vol_down': RemoteButtonData(label: 'Vol -', code: 'VDN', icon: Icons.volume_down),
    'base_up': RemoteButtonData(label: 'base +', code: 'BUP', icon: Icons.surround_sound),
    'base_down': RemoteButtonData(label: 'base -', code: 'BDN', icon: Icons.surround_sound_outlined),

    // Channel
    'ch_up': RemoteButtonData(label: 'Ch +', code: 'CUP', icon: Icons.keyboard_arrow_up),
    'ch_down': RemoteButtonData(label: 'Ch -', code: 'CDN', icon: Icons.keyboard_arrow_down),

    // Numbers
    'num_1': RemoteButtonData(label: '1', code: 'N1'),
    'num_2': RemoteButtonData(label: '2', code: 'N2'),
    'num_3': RemoteButtonData(label: '3', code: 'N3'),
    'num_4': RemoteButtonData(label: '4', code: 'N4'),
    'num_5': RemoteButtonData(label: '5', code: 'N5'),
    'num_6': RemoteButtonData(label: '6', code: 'N6'),
    'num_7': RemoteButtonData(label: '7', code: 'N7'),
    'num_8': RemoteButtonData(label: '8', code: 'N8'),
    'num_9': RemoteButtonData(label: '9', code: 'N9'),
    'num_0': RemoteButtonData(label: '0', code: 'N0'),

    // Navigation
    'up': RemoteButtonData(label: 'Up', code: 'CUP_NAV', icon: Icons.arrow_drop_up),
    'down': RemoteButtonData(label: 'Down', code: 'CDN_NAV', icon: Icons.arrow_drop_down),
    'left': RemoteButtonData(label: 'Left', code: 'CLF', icon: Icons.arrow_left),
    'right': RemoteButtonData(label: 'Right', code: 'CRT', icon: Icons.arrow_right),
    'ok': RemoteButtonData(label: 'OK', code: 'OK', icon: Icons.check_circle_outline),
    'back': RemoteButtonData(label: 'Back', code: 'BCK', icon: Icons.undo),
    'home': RemoteButtonData(label: 'Home', code: 'HME', icon: Icons.home),

    // --- AC / Fan Buttons ---
    'power_on': RemoteButtonData(label: 'ON', code: 'PON', icon: Icons.power),
    'power_off': RemoteButtonData(label: 'OFF', code: 'POFF', icon: Icons.power_off_outlined),
    'mode': RemoteButtonData(label: 'Mode', code: 'MOD', icon: Icons.autorenew),
    'temp_up': RemoteButtonData(label: 'Temp +', code: 'TUP', icon: Icons.add),
    'temp_down': RemoteButtonData(label: 'Temp -', code: 'TDN', icon: Icons.remove),
    'speed': RemoteButtonData(label: 'Speed', code: 'SPD', icon: Icons.air),
    // 'direction': REMOVED
    'swing': RemoteButtonData(label: 'Swing', code: 'SWG', icon: Icons.swap_vert),

    // AC Fan Speeds
    'fan_auto': RemoteButtonData(label: 'Auto', code: 'FAUTO', icon: Icons.hdr_auto),
    'fan_low': RemoteButtonData(label: 'Low', code: 'FLOW', icon: Icons.signal_cellular_alt_1_bar),
    'fan_med': RemoteButtonData(label: 'Med', code: 'FMED', icon: Icons.signal_cellular_alt),
    'fan_high': RemoteButtonData(label: 'High', code: 'FHIGH', icon: Icons.signal_cellular_4_bar),

    // AC Temps
    'temp_16': RemoteButtonData(label: '16°C', code: 'T16'),
    'temp_17': RemoteButtonData(label: '17°C', code: 'T17'),
    'temp_18': RemoteButtonData(label: '18°C', code: 'T18'),
    'temp_19': RemoteButtonData(label: '19°C', code: 'T19'),
    'temp_20': RemoteButtonData(label: '20°C', code: 'T20'),
    'temp_21': RemoteButtonData(label: '21°C', code: 'T21'),
    'temp_22': RemoteButtonData(label: '22°C', code: 'T22'),
    'temp_23': RemoteButtonData(label: '23°C', code: 'T23'),
    'temp_24': RemoteButtonData(label: '24°C', code: 'T24'),
    'temp_25': RemoteButtonData(label: '25°C', code: 'T25'),
    'temp_26': RemoteButtonData(label: '26°C', code: 'T26'),
    'temp_27': RemoteButtonData(label: '27°C', code: 'T27'),
    'temp_28': RemoteButtonData(label: '28°C', code: 'T28'),
    'temp_29': RemoteButtonData(label: '29°C', code: 'T29'),
    'temp_30': RemoteButtonData(label: '30°C', code: 'T30'),

    // Fan-specific
    'speed_inc': RemoteButtonData(label: 'Speed +', code: 'INC', icon: Icons.add),
    'speed_dec': RemoteButtonData(label: 'Speed -', code: 'DNC', icon: Icons.remove),
    'timer': RemoteButtonData(label: 'Timer', code: 'TMR', icon: Icons.timer),
    'sleep': RemoteButtonData(label: 'Sleep', code: 'SLP', icon: Icons.nights_stay),
    'light': RemoteButtonData(label: 'Light', code: 'LGT', icon: Icons.lightbulb),
  };

  // --- TEMPLATES ---

  static final Map<String, List<String>> _topGridTemplate = {
    'TV': [ 'power', 'source', 'mute' ],
    'BOX': [ 'power', 'source', 'mute' ],
    'SPEAKER': [], 'AC': [], 'FAN': [],
    'OTHER': [ 'power' ]
  };

  static final Map<String, List<String>> _controlPadTemplate = {
    'TV': [
      'vol_up', 'vol_down', 'ch_up', 'ch_down',
      'up', 'down', 'left', 'right', 'ok', 'back', 'home'
    ],
    'BOX': [
      'vol_up', 'vol_down', 'ch_up', 'ch_down',
      'up', 'down', 'left', 'right', 'ok', 'back', 'home'
    ],
    'SPEAKER': [],
    'AC': [],
    'FAN': [],
    'OTHER': [ 'vol_up', 'vol_down' ]
  };

  static final Map<String, List<String>> _numpadTemplate = {
    'TV': [ 'num_1', 'num_2', 'num_3', 'num_4', 'num_5', 'num_6', 'num_7', 'num_8', 'num_9', 'num_0' ],
    'BOX': [ 'num_1', 'num_2', 'num_3', 'num_4', 'num_5', 'num_6', 'num_7', 'num_8', 'num_9', 'num_0' ],
    'SPEAKER': [], 'AC': [], 'FAN': [], 'OTHER': []
  };

  static final Map<String, List<String>> _speakerGridTemplate = {
    'TV': [], 'BOX': [], 'AC': [], 'FAN': [], 'OTHER': [],
    'SPEAKER': [ 'power', 'mute', 'vol_up', 'vol_down', 'base_up', 'base_down', 'source' ],
  };

  static final Map<String, List<String>> _acLayoutTemplate = {
    'TV': [], 'BOX': [], 'SPEAKER': [], 'FAN': [], 'OTHER': [],
    'AC': [
      'power', 'mode', 'speed', 'swing', 'temp_down', 'temp_up', // Removed 'direction'
      'fan_auto', 'fan_low', 'fan_med', 'fan_high'
    ],
  };

  static final Map<String, List<String>> _simpleGridTemplate = {
    'TV': [], 'BOX': [], 'SPEAKER': [], 'AC': [], 'OTHER': [],
    'FAN': [ 'power', 'speed_inc', 'speed_dec', 'timer', 'sleep', 'light', 'num_1', 'num_2', 'num_3', 'num_4', 'num_5', 'num_6'],
  };

  // --- PUBLIC HELPER FUNCTIONS ---

  static RemoteButtonData? getButtonData(String buttonName) => _buttonMap[buttonName];

  static List<String> getButtonsForTemplate(String deviceType) {
    String type = _topGridTemplate.containsKey(deviceType) ? deviceType : 'OTHER';

    if (deviceType == 'AC') return _acLayoutTemplate['AC']!;
    if (deviceType == 'FAN') return _simpleGridTemplate['FAN']!;

    return [
      ..._topGridTemplate[type] ?? [],
      ..._controlPadTemplate[type] ?? [],
      ..._numpadTemplate[type] ?? [],
      ..._speakerGridTemplate[type] ?? [],
    ];
  }

  static List<String> getTopGridButtons(String deviceType) => _topGridTemplate[deviceType] ?? _topGridTemplate['OTHER']!;
  static List<String> getControlPadButtons(String deviceType) => _controlPadTemplate[deviceType] ?? _controlPadTemplate['OTHER']!;
  static List<String> getNumpadButtons(String deviceType) => _numpadTemplate[deviceType] ?? _numpadTemplate['OTHER']!;
  static List<String> getSimpleGridButtons(String deviceType) => _simpleGridTemplate[deviceType] ?? _simpleGridTemplate['OTHER']!;
  static List<String> getSpeakerGridButtons(String deviceType) => _speakerGridTemplate[deviceType] ?? _speakerGridTemplate['OTHER']!;
  static List<String> getAcLayoutButtons(String deviceType) => _acLayoutTemplate[deviceType] ?? [];

  static String? getButtonNameFromCode(String code) {
    for (var entry in _buttonMap.entries) {
      if (entry.value.code == code) return entry.key;
    }
    return null;
  }
}