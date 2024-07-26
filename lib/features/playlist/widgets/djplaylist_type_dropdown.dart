import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:flutter/material.dart';

class DJPlaylistTypeDropdown extends StatelessWidget {
  final String initialValue;
  final void Function(String?) onChanged;
  const DJPlaylistTypeDropdown({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return djPlaylistTypeDropdownButton<String>(
      value: initialValue,
      onChanged: onChanged,
      items: DJPlaylistType.values
          .map<DropdownMenuItem<String>>((DJPlaylistType value) {
        return DropdownMenuItem<String>(
          value: value.name,
          child: Text(value.name.toUpperCase()),
        );
      }).toList(),
    );
  }
}

Widget djPlaylistTypeDropdownButton<String>(
    {required String value,
    required void Function(String?) onChanged,
    required List<DropdownMenuItem<String>> items}) {
  return DropdownButton<String>(
    value: value,
    hint: const Text(
      "Please choose a playlist type",
      style: TextStyle(
          color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
    ),
    onChanged: (String? value) {
      onChanged(value);
    },
    items: items,
  );
}
