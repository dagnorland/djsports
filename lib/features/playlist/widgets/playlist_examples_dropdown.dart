import 'package:flutter/material.dart';

class PlaylistSpotifyUriExample {
  static const List<Map<String, String>> values = [
    {'type': 'HOTSPOT', 'uri': 'playlist:3bPnAnhr5i5CZhVWhjcvqN'},
    {'type': 'HOTSPOT', 'uri': 'playlist/7w2SzKpEX07q2ormj6aDFi'},
    {'type': 'HOTSPOT', 'uri': 'playlist:5THsvdwlxPboeXPnMCqaYH'},
    {'type': 'HOTSPOT', 'uri': 'playlist/1xzEllVUTnZm70xn4zlMkv'},
    {'type': 'MATCH', 'uri': 'playlist:3s93nj36LDDHzz0njr5P3t'},
    {'type': 'MATCH', 'uri': 'playlist:2QsZRdF8n8JbZGJmheuTvt'},
    {'type': 'MATCH', 'uri': 'playlist/1BwYcCSsMbL7U38kWU3TE8'},
    {'type': 'FUNSTUFF', 'uri': 'playlist/1NiUvxz1hjHth95BoIhpmx'},
    {'type': 'FUNSTUFF', 'uri': 'playlist/7tBoxilzbBtO5rFoErMBhr'},
    {'type': 'FUNSTUFF', 'uri': 'playlist/22GBDyfNMlTGmj6uTOst7P'},
    {'type': 'FUNSTUFF', 'uri': 'playlist:11J7lwyg9AOB2cGeYLZ8o8'},
    {'type': 'FUNSTUFF', 'uri': 'playlist:2ICHHgcQVkxfz6BnaRfEjD'},
    {'type': 'FUNSTUFF', 'uri': 'playlist/2lf6ls1KOYLww3Qqj6oP99'},
    {'type': 'PREMATCH', 'uri': 'playlist/0rMJYwKMTY9qZ3rAnOiYUN'},
    {'type': 'PREMATCH', 'uri': 'playlist/0tJ9cHK1AqMz4Hz0KKjFfT'},
    {'type': 'PREMATCH', 'uri': 'playlist/5npiOA4OTXZc3JZMEeb6tr'},
    {'type': 'PREMATCH', 'uri': 'playlist/4FZ1ewVjhSDq6Wvb1zHK4C'},
    {'type': 'PREMATCH', 'uri': 'playlist/5FndZkkown4QwMFC4KwsCq'},
    {'type': 'PREMATCH', 'uri': 'playlist:2gTKxeQWfajAzIdlNEUJBc'},
    {'type': 'PREMATCH', 'uri': 'playlist:0RPNCAg3M3NtoFIU4QoU30'},
  ];
}

class PlaylistSpotifyUriExampleDropdown extends StatelessWidget {
  final String initialValue;
  final List<String> existingUris;
  final void Function(String?) onChanged;

  const PlaylistSpotifyUriExampleDropdown({
    super.key,
    required this.initialValue,
    required this.existingUris,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownItems = PlaylistSpotifyUriExample.values
        .where((item) => !existingUris.contains(item['uri']))
        .map<DropdownMenuItem<String>>((Map<String, String> item) {
      debugPrint(item['uri']);
      return DropdownMenuItem<String>(
        value: item['uri'],
        child: Text('${item['type']} - ${item['uri']}'),
      );
    }).toList();

    return DropdownButton<String>(
      value: null,
      hint: const Text(
        'Choose example playlist',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onChanged: onChanged,
      items: dropdownItems,
    );
  }
}
