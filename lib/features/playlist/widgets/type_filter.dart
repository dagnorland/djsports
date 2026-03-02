import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TypeFilter extends HookConsumerWidget {
  const TypeFilter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(typeFilterPlaylistProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: DJPlaylistType.values
            .map(
              (type) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: status == type
                        ? Theme.of(context).primaryColor
                        : null,
                    foregroundColor: status != type
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    ref.read(typeFilterPlaylistProvider.notifier).state = type;
                  },
                  child: Text(
                    type.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
