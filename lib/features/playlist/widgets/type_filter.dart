import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils.dart';

class TypeFilter extends HookConsumerWidget {
  const TypeFilter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(typeFilterProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: Type.values
          .map(
            (type) => InkWell(
              child: SizedBox(
                width: 110,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      backgroundColor: status == type
                          ? Theme.of(context).primaryColor
                          : null,
                      foregroundColor: status != type
                          ? Theme.of(context).primaryColor
                          : Colors.white),
                  onPressed: () {
                    ref.read(typeFilterProvider.notifier).state = type;
                  },
                  child: Text(
                    type.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
