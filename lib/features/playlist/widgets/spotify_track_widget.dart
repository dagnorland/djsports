import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';

class SpotifyTrackSearchResultTile extends StatelessWidget {
  const SpotifyTrackSearchResultTile(
      {super.key,
      required this.track,
      required this.existInPlaylist,
      required this.onSelected});
  final Track track;
  final bool existInPlaylist;
  final ValueChanged<Track> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: () => existInPlaylist ? null : onSelected(track),
      child: Column(
        children: [
          if (track.album!.images!.first.url != null)
            SizedBox(
                height: 130,
                width: 130,
                child: ClipPath(
                  clipper: const ShapeBorderClipper(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: track.album!.images!.first.url!,
                  ),
                )),
          const SizedBox(height: 8.0),
          Text(
            maxLines: 1,
            track.name!,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.start,
          ),
          Text(
            maxLines: 1,
            track.artists!.first.name!,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
          Text(
            track.duration != null
                ? track.duration.toString().substring(2, 7)
                : '',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}

class SearchPlaceholder extends StatelessWidget {
  const SearchPlaceholder({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        title,
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
