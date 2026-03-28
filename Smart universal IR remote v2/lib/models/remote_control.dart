import 'dart:convert';

class RemoteControl {
  String name;
  Map<String, String> codes;
  String deviceType;
  List<String> buttons; // <-- NEW: Stores the button layout

  RemoteControl({
    required this.name,
    Map<String, String>? codes,
    String? deviceType,
    List<String>? buttons, // <-- NEW
  })  : codes = codes ?? {},
        deviceType = deviceType ?? 'OTHER',
        buttons = buttons ?? []; // <-- NEW (default to empty list)

  Map<String, dynamic> toJson() => {
    'name': name,
    'codes': codes,
    'deviceType': deviceType,
    'buttons': buttons, // <-- NEW
  };

  factory RemoteControl.fromJson(Map<String, dynamic> json) {
    return RemoteControl(
      name: json['name'],
      codes: Map<String, String>.from(json['codes'] ?? {}),
      deviceType: json['deviceType'] ?? 'OTHER',
      buttons: List<String>.from(json['buttons'] ?? []), // <-- NEW
    );
  }

  String toJsonString() => json.encode(toJson());

  factory RemoteControl.fromJsonString(String jsonString) =>
      RemoteControl.fromJson(json.decode(jsonString));
}