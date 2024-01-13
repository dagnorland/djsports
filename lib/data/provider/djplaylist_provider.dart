import 'package:djsports/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../controller/djplaylist_controller.dart';
import '../models/djplaylist_model.dart';
import '../repo/djplaylist_repository.dart';

///filtered data based on user todo status

final typeFilterProvider = StateProvider<Type>((ref) => Type.all);

/// Filtered Todo List

final typeFilteredDataProvider = Provider<List<DJPlaylist>>(
  (ref) {
    final hiveDatas = ref.watch(hiveData);
    final typeData = hiveDatas!;
    final type = ref.watch(typeFilterProvider);
    if (type == Type.all) {
      return hiveDatas.toList();
    }

    List<DJPlaylist> myData =
        typeData.where((todo) => todo.type == type.name).toList();
    return myData;
  },
);

///Category Selection
final selectedRadioProvider = StateProvider<int>((ref) => 0);

///Todo RepoProvider
final providerHive = Provider<DJPlaylistRepo>((ref) => DJPlaylistRepo());

///Hive data

final hiveData = StateNotifierProvider<DJPlaylistHive, List<DJPlaylist>?>(
    (ref) => DJPlaylistHive(ref));
