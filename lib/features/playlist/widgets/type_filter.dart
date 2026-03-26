import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TypeFilter extends HookConsumerWidget {
  const TypeFilter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(typeFilterPlaylistProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            'Filter:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                ),
          ),
          const SizedBox(width: 8),
          DropdownButton<DJPlaylistType>(
            value: selected,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
            icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.black38),
            items: DJPlaylistType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name),
                  ),
                )
                .toList(),
            onChanged: (type) {
              if (type != null) {
                ref.read(typeFilterPlaylistProvider.notifier).state = type;
              }
            },
          ),
        ],
      ),
    );
  }
}
