import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/utils.dart';
import 'package:flutter/material.dart';
// Localization
//models

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';

//Providers

class EditScreen extends StatefulHookConsumerWidget {
  const EditScreen({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.isNew,
    required this.id,
    this.status,
    required this.index,
  });
  final String name;
  final String type;
  final String spotifyUri;
  final String id;
  final bool isNew;
  final String? status;
  final int index;
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  final nameController = TextEditingController();
  final spotifyUriController = TextEditingController();
  Type selectedType = Type.score;

  @override
  void initState() {
    if (!widget.isNew) {
      nameController.text = widget.name;
      spotifyUriController.text = widget.spotifyUri;
    }
    selectedType = Type.values.firstWhere((e) => e.name == widget.type);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 30,
            )),
        title: Text(
          widget.id.isEmpty ? "Create Playlist" : "Edit Playlist",
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                hintText: ' Enter name',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextField(
                controller: spotifyUriController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  hintText: ' Paste spotify uri',
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                child: DropdownButtonHideUnderline(
                    child: DropdownButton<Type>(
                  value: selectedType,
                  items: Type.values.map((Type type) {
                    return DropdownMenuItem<Type>(
                      value: type,
                      child: Text(type.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (Type? newValue) {
                    setState(() {
                      ref.read(typeFilterProvider.notifier).state = newValue!;
                    });
                  },
                ))),
            const SizedBox(
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                const SizedBox(
                  width: 30,
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  onPressed: () {
                    if (widget.id.isEmpty) {
                      ref.read(hiveData.notifier).addDJplaylist(
                            DJPlaylist(
                              name: nameController.text,
                              type: selectedType.name,
                              spotifyUri: spotifyUriController.text,
                              shuffleAtEnd: false,
                              trackIds: [],
                              currentTrack: 0,
                              playCount: 0,
                              autoNext: false,
                            ),
                          );
                    } else {
                      ref.read(hiveData.notifier).updateDJPlaylist(
                            DJPlaylist(
                              name: nameController.text,
                              type: selectedType.name,
                              spotifyUri: spotifyUriController.text,
                              shuffleAtEnd: false,
                              trackIds: [],
                              currentTrack: 0,
                              playCount: 0,
                              autoNext: false,
                            ),
                          );
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    widget.id.isEmpty ? 'Create' : 'Update',
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
