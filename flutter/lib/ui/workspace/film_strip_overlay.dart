// The films, floating over the foot of the canvas: one tile each, the chosen one ringed. The strip
// takes no room from the picture — it is drawn over it — and fades away as a drawer opens, so a
// phone can give the whole screen to the photograph.
import 'package:flutter/widgets.dart';

import '../../model/editor.dart';
import '../theme/theme.dart';
import 'film_library.dart' show ShownFilmRow, StripTile;

class FilmStripOverlay extends StatefulWidget {
  const FilmStripOverlay({super.key, required this.editor});
  final EditorModel editor;

  @override
  State<FilmStripOverlay> createState() => _FilmStripOverlayState();
}

class _FilmStripOverlayState extends State<FilmStripOverlay> {
  final _scroll = ScrollController();

  /// Whether the strip has been brought round to the chosen film.
  bool _placed = false;

  /// How many of the films had a picture when the strip last drew. A tile that arrives while the
  /// strip is scrolled still has to be redrawn, and the strip is rebuilt for the picture rather
  /// than for every notification the editor sends.
  int _drawn = -1;

  EditorModel get editor => widget.editor;

  @override
  void initState() {
    super.initState();
    editor.addListener(_picturesArrived);
  }

  @override
  void dispose() {
    editor.removeListener(_picturesArrived);
    _scroll.dispose();
    super.dispose();
  }

  void _picturesArrived() {
    final count = editor.active?.filmThumbnails.images.length ?? 0;
    if (count == _drawn || !mounted) return;
    setState(() => _drawn = count);
  }

  /// Every film, Normal first, as the library lists them.
  List<Json?> get _films => [null, ...editor.stocks];

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final doc = editor.active;
    if (doc == null) return const SizedBox.shrink();
    _drawn = doc.filmThumbnails.images.length;
    final films = _films;
    final selected = editor.edit['stock'] as String?;
    const extent = Metrics.filmStripTile + Metrics.filmStripGap;
    if (!_placed) {
      _placed = true;
      final index = films.indexWhere((s) => s?['id'] == selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients || index <= 0) return;
        final position = _scroll.position;
        _scroll.jumpTo((index * extent - (position.viewportDimension - extent) / 2)
            .clamp(0, position.maxScrollExtent));
      });
    }
    return Container(
      height: 86,
      decoration: BoxDecoration(
        // The canvas shows through a little, so the strip reads as floating over the picture.
        color: palette.panel.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: .5)),
      ),
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        // Tiles are built as they come into view, which is when their pictures develop.
        cacheExtent: 0,
        itemExtent: extent,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        itemCount: films.length,
        itemBuilder: (context, index) {
          final stock = films[index];
          final id = stock?['id'] as String?;
          return Align(
            alignment: Alignment.centerLeft,
            // Registered as shown, so the engine develops this film's picture at all: a row it
            // never hears about stays on the imported photograph.
            child: ShownFilmRow(
              editor: editor,
              id: id ?? '',
              child: StripTile(
                name: stock?['name'] as String? ?? 'Normal',
                thumbnail: doc.filmThumbnails[id ?? ''] ?? doc.importPicture,
                selected: id == selected,
                thumb: 52,
                nameLines: 1,
                onPressed: () => editor.chooseStock(id),
              ),
            ),
          );
        },
      ),
    );
  }
}
