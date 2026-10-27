// The Add media menu: what to import — a photograph from the gallery, one from the file manager, a
// video, or a scanned negative — and exposures to merge into trichromatic scans. The desktop
// toolbar shows it behind an icon; the phone's film drawer behind a bar at its foot.
import 'package:flutter/widgets.dart';

import '../../model/editor.dart';
import '../../model/l10n.dart';
import '../kit/kit.dart';
import '../theme/theme.dart';

/// What the Add media control opens, from wherever it is anchored.
void showImportMenu(
  BuildContext anchor,
  EditorModel editor, {
  required VoidCallback onGallery,
  required VoidCallback onFiles,
  double width = 220,
}) {
  final scans = editor.negatives;
  showMenu(anchor, width: width, [
    MenuItem(label: t('Photos…'), onSelected: editor.ready ? onGallery : null),
    MenuItem(label: t('From Files…'), onSelected: editor.ready ? onFiles : null),
    MenuItem(label: t('Video…'), onSelected: editor.ready ? editor.video.chooseMovies : null),
    MenuItem(label: t('Negative…'), onSelected: scans.canImport ? scans.chooseNegatives : null),
    if (editor.engine?.opensPaths ?? true)
      MenuItem(
          label: t('Trichromatic Negative…'),
          onSelected: scans.canMerge ? scans.chooseExposures : null),
  ]);
}

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
  Widget build(BuildContext context) => Builder(
        builder: (anchor) => QuietButton(
          icon: 'plus',
          tooltip: t('Add media'),
          size: size,
          opensMenu: true,
          onPressed: editor.exporting
              ? null
              : () => showImportMenu(anchor, editor, onGallery: onGallery, onFiles: onFiles),
        ),
      );
}
