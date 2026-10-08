import 'dart:io';
import 'dart:math';

import 'package:djsports/core/theme/stage_colors.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/features/djsports/widgets/playlist_card.dart';
import 'package:flutter/material.dart';

/// The home page's playlists, Spotify-style: chips to pick a type at the
/// top; "All" shows one horizontal shelf per type, a single type shows a
/// grid. Reorder within a shelf (the order drives Let's Play): long-press
/// and drag on touch devices, grab and drag with the mouse on desktop.
/// Works in phone portrait (~2.2 cards per shelf) and in tablet/Mac
/// landscape (210 px cards).
class PlaylistBrowser extends StatefulWidget {
  const PlaylistBrowser({
    super.key,
    required this.playlists,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<DJPlaylist> playlists;
  final void Function(DJPlaylist) onEdit;
  final void Function(DJPlaylist) onDelete;
  final void Function(String typeName, int oldIndex, int newIndex) onReorder;

  @override
  State<PlaylistBrowser> createState() => _PlaylistBrowserState();
}

class _PlaylistBrowserState extends State<PlaylistBrowser> {
  /// null = All.
  DJPlaylistType? _filter;

  /// Types in the home page's order, each sorted by its position.
  List<(DJPlaylistType, List<DJPlaylist>)> get _sections => [
    for (final type in DJPlaylistType.values)
      if (type != DJPlaylistType.all)
        (
          type,
          widget.playlists.where((p) => p.type == type.name).toList()
            ..sort((a, b) => a.position.compareTo(b.position)),
        ),
  ].where((s) => s.$2.isNotEmpty).toList();

  Widget _shelf((DJPlaylistType, List<DJPlaylist>) section, double cardWidth) {
    final (type, playlists) = section;
    return _Shelf(
      type: type,
      playlists: playlists,
      cardWidth: cardWidth,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
      onReorder: (o, n) => widget.onReorder(type.name, o, n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    // A filter whose type has no playlists any more falls back to All.
    if (_filter != null && !sections.any((s) => s.$1 == _filter)) {
      _filter = null;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Phones: ~2.2 cards per shelf; wide screens: fixed 210 px.
        final cardWidth = (width >= 700 ? 210.0 : (width - 32) / 2.2).clamp(
          140.0,
          230.0,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TypeChips(
              sections: sections,
              selected: _filter,
              total: widget.playlists.length,
              onSelected: (type) => setState(() => _filter = type),
            ),
            Expanded(
              child: _filter == null
                  ? ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final row in _pairUp(sections, cardWidth, width))
                          // Two neighbouring sections side by side when both
                          // fit in half the width (wide screens), so more
                          // playlists show without scrolling.
                          row.length == 1
                              ? _shelf(row.first, cardWidth)
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _shelf(row.first, cardWidth),
                                    ),
                                    const SizedBox(width: _pairGap),
                                    Expanded(
                                      child: _shelf(row.last, cardWidth),
                                    ),
                                  ],
                                ),
                      ],
                    )
                  : _TypeGrid(
                      playlists: sections.firstWhere((s) => s.$1 == _filter).$2,
                      maxCardWidth: max(cardWidth * 1.25, 160),
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Mouse-driven platforms: drag a card directly instead of long-press.
final _isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Space between two sections shown side by side.
const _pairGap = 24.0;

/// Width a shelf needs to show all its cards without scrolling (cards with
/// 8 px padding each side, plus the list's 8 px padding at both ends).
double _shelfWidth(int cards, double cardWidth) =>
    cards * (cardWidth + 16) + 16;

/// Groups sections into rows: two neighbours share a row when both fit in
/// half of [width]; otherwise a section gets the row to itself. The order
/// stays left-to-right, top-to-bottom.
List<List<(DJPlaylistType, List<DJPlaylist>)>> _pairUp(
  List<(DJPlaylistType, List<DJPlaylist>)> sections,
  double cardWidth,
  double width,
) {
  final half = (width - _pairGap) / 2;
  bool fits((DJPlaylistType, List<DJPlaylist>) s) =>
      _shelfWidth(s.$2.length, cardWidth) <= half;
  final rows = <List<(DJPlaylistType, List<DJPlaylist>)>>[];
  var i = 0;
  while (i < sections.length) {
    if (i + 1 < sections.length && fits(sections[i]) && fits(sections[i + 1])) {
      rows.add([sections[i], sections[i + 1]]);
      i += 2;
    } else {
      rows.add([sections[i]]);
      i += 1;
    }
  }
  return rows;
}

String _typeLabel(DJPlaylistType type) => switch (type) {
  DJPlaylistType.hotspot => 'Hotspot',
  DJPlaylistType.match => 'Match',
  DJPlaylistType.funStuff => 'Fun Stuff',
  DJPlaylistType.preMatch => 'Pre-match',
  DJPlaylistType.archived => 'Archived',
  DJPlaylistType.all => 'All',
};

class _TypeChips extends StatelessWidget {
  const _TypeChips({
    required this.sections,
    required this.selected,
    required this.total,
    required this.onSelected,
  });

  final List<(DJPlaylistType, List<DJPlaylist>)> sections;
  final DJPlaylistType? selected;
  final int total;
  final ValueChanged<DJPlaylistType?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
      Color? dot,
      Color? fill,
    }) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        selected: isSelected,
        onSelected: (_) => onTap(),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: StageColors.surfaceHigh,
        selectedColor: fill ?? StageColors.text,
        avatar: dot == null
            ? null
            : CircleAvatar(
                radius: 5,
                backgroundColor: isSelected ? Colors.white : dot,
              ),
        label: Text(label),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: isSelected
              ? (fill == null ? Colors.black : Colors.white)
              : StageColors.text,
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          chip(
            label: 'All $total',
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final (type, playlists) in sections)
            chip(
              label: '${_typeLabel(type)} ${playlists.length}',
              isSelected: selected == type,
              dot: stageTypeColor(type.color, context),
              fill: stageTypeColor(type.color, context),
              onTap: () => onSelected(type),
            ),
        ],
      ),
    );
  }
}

/// One type as a horizontal row of cards, like a Spotify shelf.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.type,
    required this.playlists,
    required this.cardWidth,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final DJPlaylistType type;
  final List<DJPlaylist> playlists;
  final double cardWidth;
  final void Function(DJPlaylist) onEdit;
  final void Function(DJPlaylist) onDelete;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final color = stageTypeColor(type.color, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(width: 4, height: 18, color: color),
              const SizedBox(width: 8),
              Text(
                _typeLabel(type).toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${playlists.length}',
                style: const TextStyle(
                  color: StageColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardWidth + PlaylistCard.textHeight,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            buildDefaultDragHandles: false,
            itemCount: playlists.length,
            onReorder: onReorder,
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, child: child),
            itemBuilder: (context, i) {
              final playlist = playlists[i];
              final card = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: cardWidth,
                  child: PlaylistCard(
                    playlist: playlist,
                    onEdit: () => onEdit(playlist),
                    onDelete: () => onDelete(playlist),
                  ),
                ),
              );
              // Desktop: grab with the mouse and drag (a click still
              // edits). Touch: long-press, so a swipe scrolls the shelf.
              return _isDesktop
                  ? ReorderableDragStartListener(
                      key: ValueKey(playlist.id),
                      index: i,
                      child: card,
                    )
                  : ReorderableDelayedDragStartListener(
                      key: ValueKey(playlist.id),
                      index: i,
                      child: card,
                    );
            },
          ),
        ),
      ],
    );
  }
}

/// A single type as a grid of bigger cards.
class _TypeGrid extends StatelessWidget {
  const _TypeGrid({
    required this.playlists,
    required this.maxCardWidth,
    required this.onEdit,
    required this.onDelete,
  });

  final List<DJPlaylist> playlists;
  final double maxCardWidth;
  final void Function(DJPlaylist) onEdit;
  final void Function(DJPlaylist) onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 20.0;
        const padding = 16.0;
        final inner = constraints.maxWidth - padding * 2;
        final cols = max(
          1,
          ((inner + spacing) / (maxCardWidth + spacing)).ceil(),
        );
        final cardWidth = (inner - spacing * (cols - 1)) / cols;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(padding, 8, padding, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardWidth + PlaylistCard.textHeight,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, i) => PlaylistCard(
            playlist: playlists[i],
            onEdit: () => onEdit(playlists[i]),
            onDelete: () => onDelete(playlists[i]),
          ),
        );
      },
    );
  }
}
