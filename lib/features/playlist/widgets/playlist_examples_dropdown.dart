import 'package:flutter/material.dart';

class PlaylistSpotifyUriExample {
  static const List<Map<String, String>> values = [
    {
      'type': 'HOTSPOT',
      'uri': 'playlist/7w2SzKpEX07q2ormj6aDFi',
      'name': 'Score Hjemme 1'
    },
    {
      'type': 'HOTSPOT',
      'uri': 'playlist/6fJXMdlIVFtbcHBFeViWqr',
      'name': 'Score Hjemme 2'
    },
    {
      'type': 'HOTSPOT',
      'uri': 'playlist/3bPnAnhr5i5CZhVWhjcvqN',
      'name': 'Score Borte'
    },
    {
      'type': 'HOTSPOT',
      'uri': 'playlist/3CowNHNZXYom1JqwdFHQal',
      'name': 'Chill 2'
    },
    {
      'type': 'HOTSPOT',
      'uri': 'playlist/1pbQjl2mNrIzBBqZKTgqQ7',
      'name': 'Pump It Up!'
    },
    {
      'type': 'MATCH',
      'uri': 'playlist/3s93nj36LDDHzz0njr5P3t',
      'name': 'Funk Off'
    },
    {
      'type': 'FUNSTUFF',
      'uri': 'playlist/2ICHHgcQVkxfz6BnaRfEjD',
      'name': 'Intervensjon'
    },
    {'type': '--------', 'uri': '--------------------------------', 'name': ''},
    {'type': 'HOTSPOT', 'uri': 'playlist:5THsvdwlxPboeXPnMCqaYH', 'name': ''},
    {'type': 'HOTSPOT', 'uri': 'playlist/1xzEllVUTnZm70xn4zlMkv', 'name': ''},
    {'type': 'MATCH', 'uri': 'playlist:2QsZRdF8n8JbZGJmheuTvt', 'name': ''},
    {'type': 'MATCH', 'uri': 'playlist/1BwYcCSsMbL7U38kWU3TE8', 'name': ''},
    {'type': 'FUNSTUFF', 'uri': 'playlist/1NiUvxz1hjHth95BoIhpmx', 'name': ''},
    {'type': 'FUNSTUFF', 'uri': 'playlist/7tBoxilzbBtO5rFoErMBhr', 'name': ''},
    {'type': 'FUNSTUFF', 'uri': 'playlist/22GBDyfNMlTGmj6uTOst7P', 'name': ''},
    {'type': 'FUNSTUFF', 'uri': 'playlist:11J7lwyg9AOB2cGeYLZ8o8', 'name': ''},
    {'type': 'FUNSTUFF', 'uri': 'playlist/2lf6ls1KOYLww3Qqj6oP99', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist/0rMJYwKMTY9qZ3rAnOiYUN', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist/0tJ9cHK1AqMz4Hz0KKjFfT', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist/5npiOA4OTXZc3JZMEeb6tr', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist/4FZ1ewVjhSDq6Wvb1zHK4C', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist/5FndZkkown4QwMFC4KwsCq', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist:2gTKxeQWfajAzIdlNEUJBc', 'name': ''},
    {'type': 'PREMATCH', 'uri': 'playlist:0RPNCAg3M3NtoFIU4QoU30', 'name': ''},
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
      return DropdownMenuItem<String>(
        value: item['uri'],
        child: Text('${item['type']} - ${item['name']} - ${item['uri']}'),
      );
    }).toList();

    return DropdownButton<String>(
      value: null,
      hint: const Text(
        'Choose example playlist - if any spotify uri is empty',
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
