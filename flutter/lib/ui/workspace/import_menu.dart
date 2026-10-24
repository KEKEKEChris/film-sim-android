// The toolbar's Add media button: a menu of what to import — a photograph from the gallery, one
// from the file manager, a video, or a scanned negative — and exposures to merge into
// trichromatic scans.
import 'package:flutter/widgets.dart';

import '../../model/editor.dart';
import '../kit/kit.dart';
import '../theme/theme.dart';

class ImportMenu extends StatelessWidget {
  const ImportMenu(
      {super.key,
      required this.editor,
      required this.onGallery,
      required this.onFiles,
      this.size = Metrics.control});
  final EditorModel editor;

  /// The system photo picker: the gallery, which is what a photo app's import means by default.
  final VoidCallback onGallery;

  /// The file manager, for a RAW on an SD card or a scan no gallery has indexed.
  final VoidCallback onFiles;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scans = editor.negatives;
    return Builder(
      builder: (anchor) => QuietButton(
        icon: 'plus',
        tooltip: 'Add media',
        size: size,
        opensMenu: true,
        onPressed: editor.exporting
            ? null
            : () => showMenu(anchor, width: 220, [
                  MenuItem(label: 'Photos…', onSelected: editor.ready ? onGallery : null),
                  MenuItem(label: 'From Files…', onSelected: editor.ready ? onFiles : null),
                  MenuItem(
                      label: 'Video…',
                      onSelected: editor.ready ? editor.video.chooseMovies : null),
                  MenuItem(
                      label: 'Negative…',
                      onSelected: scans.canImport ? scans.chooseNegatives : null),
                  if (editor.engine?.opensPaths ?? true)
                    MenuItem(
                        label: 'Trichromatic Negative…',
                        onSelected: scans.canMerge ? scans.chooseExposures : null),
                ]),
      ),
    );
  }
}
