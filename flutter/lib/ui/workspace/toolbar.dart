// The editor's toolbar, compact: 40 px in the panels' colour. The brand, the library and Add media
// on the left, zoom and the canvas tools in the middle, the histogram, history, export, More and
// the inspector on the right. On macOS it is the titlebar: its empty space drags the window.
import 'dart:math' as math;

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter/widgets.dart';

import '../../app/commands.dart';
import '../../app/editor_shortcuts.dart' show shortcutLabel;
import '../../app/host_window.dart';
import '../../app/touch_scale.dart' show mobilePlatform;
import '../../model/app_dialogs.dart';
import '../../model/editor.dart';
import '../../model/library_files.dart' show libraryFilesAvailable;
import '../../model/panel_layout.dart' show PanelSide;
import '../../model/presets.dart' show pasteTitle;
import '../kit/kit.dart';
import '../theme/theme.dart';
import 'export_progress.dart';
import 'film_pack_notice.dart';
import 'import_menu.dart';
import 'support_dialog.dart';
import 'viewer_status.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key, required this.commands});

  final EditorCommands commands;
  EditorModel get editor => commands.editor;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final titlebar = HostWindow.toolbarIsTitlebar;
    // As the title bar, the colour is painted behind the controls by the window's drag and zoom
    // surface (below), so a press on empty space reaches it.
    final colour = titlebar ? null : palette.panel;
    // A tablet lays out three columns but keeps the phone's three things in its bar.
    final touch = editor.layout.compact || mobilePlatform;
    final bar = touch ? _compact(colour, titlebar) : Container(
      height: Metrics.toolbarHeight,
      color: colour,
      padding: const EdgeInsets.symmetric(horizontal: Metrics.toolbarPadding),
      child: Row(children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: Metrics.toolbarLeadingWidth),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // The traffic lights sit in the toolbar's leading inset.
            if (titlebar) const SizedBox(width: Metrics.trafficLightInset),
            const SizedBox(width: 7),
            const LatentImageBrand(),
            const SizedBox(width: 8),
            // A browser reads no folders, so it has no library.
            if (libraryFilesAvailable) _LibraryButton(editor: editor),
            ImportMenu(
                editor: editor,
                onGallery: commands.actions.openGallery,
                onFiles: commands.actions.openFiles),
          ]),
        ),
        // The library hides the photograph's controls.
        Expanded(child: _whileEditing(_ViewGroup(editor: editor))),
        _whileEditing(_EditGroup(commands: commands)),
      ]),
    );
    // Under a phone's status bar, the bar's colour runs up behind it.
    final inset = MediaQuery.paddingOf(context).top;
    if (!titlebar) {
      if (inset == 0) return bar;
      return ColoredBox(
          color: palette.panel,
          child: Padding(padding: EdgeInsets.only(top: inset), child: bar));
    }
    // Empty space drags and zooms the window, as a title bar does. The surface sits behind the
    // controls rather than around them: its double-click would otherwise hold every button's
    // press in the gesture arena until a second click could no longer come.
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => HostWindow.startDrag(),
          onDoubleTap: HostWindow.zoom,
          child: ColoredBox(color: palette.panel),
        ),
      ),
      bar,
    ]);
  }

  Widget _whileEditing(Widget child) => Visibility(
      visible: !editor.library.open,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: child);
}

/// The compact layout's toolbar, three things and no more: back, the film the photograph is being
/// developed in over its name, and Export. Adding media lives at the foot of the film drawer, the
/// panels in the rail below, and the histogram, Reset and undo in More.
extension on EditorToolbar {
  Widget _compact(Color? colour, bool titlebar) => Container(
        height: Metrics.compactToolbarRow,
        color: colour,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          if (titlebar) const SizedBox(width: Metrics.trafficLightInset),
          _BackButton(editor: editor),
          const SizedBox(width: 2),
          Expanded(child: _TitleBlock(editor: editor)),
          _whileEditing(Row(mainAxisSize: MainAxisSize.min, children: [
            if (editor.exporter.busy) ...[
              ExportProgressButton(editor: editor, size: Metrics.compactTouch),
              const SizedBox(width: 2),
            ],
            _ExportPill(commands: commands),
            _MoreButton(commands: commands),
          ])),
        ]),
      );
}

/// The film the photograph is being developed in, by name; Normal with no film.
String _stockName(EditorModel editor) {
  final id = editor.edit['stock'] as String?;
  for (final stock in editor.stocks) {
    if (stock['id'] == id) return stock['name'] as String? ?? 'Normal';
  }
  return 'Normal';
}

/// Back out of whatever is open: a drawer, the photo library, a crop — and with nothing left to
/// close, out of the app, as a phone's back expects.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.editor});
  final EditorModel editor;

  @override
  Widget build(BuildContext context) => QuietButton(
        icon: 'chevronLeft',
        tooltip: 'Back',
        size: Metrics.compactTouch,
        onPressed: () {
          final layout = editor.layout;
          if (layout.compact && (editor.filmOpen || editor.inspectorOpen)) {
            layout.dismiss(editor.filmOpen ? PanelSide.film : PanelSide.inspector);
          } else if (editor.library.open) {
            editor.library.toggle();
          } else {
            SystemNavigator.pop();
          }
        },
      );
}

/// The photograph's film over its file name, or the app's name with nothing open.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.editor});
  final EditorModel editor;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final doc = editor.active;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(doc == null ? 'Latent Image' : _stockName(editor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: editorText(context,
                    size: TextSizes.heading, weight: FontWeight.w500, color: palette.text)
                .copyWith(letterSpacing: .1)),
        if (doc != null) ...[
          const SizedBox(height: 1),
          Text(doc.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: editorText(context, size: TextSizes.label, color: palette.muted)),
        ],
      ],
    );
  }
}

/// Export, as the one filled control on the phone.
class _ExportPill extends StatelessWidget {
  const _ExportPill({required this.commands});
  final EditorCommands commands;

  @override
  Widget build(BuildContext context) {
    final editor = commands.editor;
    return PillButton('Export',
        variant: ButtonVariant.accent,
        height: Metrics.compactPill,
        padding: 15,
        onPressed: editor.active != null && editor.stocks.isNotEmpty && !editor.exporting
            ? commands.actions.export
            : null);
  }
}

/// Everything the three-part bar has no room for.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.commands});
  final EditorCommands commands;

  @override
  Widget build(BuildContext context) => Builder(
        key: moreOptionsKey,
        builder: (anchor) => QuietButton(
          icon: 'more',
          tooltip: 'More options',
          opensMenu: true,
          size: Metrics.compactTouch,
          onPressed: () => showMoreOptions(anchor, commands),
        ),
      );
}

/// The library's toggle.
class _LibraryButton extends StatelessWidget {
  const _LibraryButton({required this.editor, this.size = Metrics.control});
  final EditorModel editor;
  final double size;

  @override
  Widget build(BuildContext context) => QuietButton(
        icon: 'library',
        tooltip: 'Library (L)',
        selected: editor.library.open,
        size: size,
        onPressed: editor.exporting ? null : editor.library.toggle,
      );
}

/// Zoom, the canvas tools and the photograph's size.
class _ViewGroup extends StatelessWidget {
  const _ViewGroup({required this.editor});
  final EditorModel editor;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final doc = editor.active;
    final photo = doc != null;
    // Where the view stands between fit and the largest zoom.
    final fit = !editor.zoomed;
    final max = editor.zoomed && editor.scale >= ViewState.maxZoom * .999;
    final cropMode = editor.crop.showing;
    // Each tool opens in the inspector.
    void open(Panel panel) => editor.layout.choosePanel(panel);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      QuietButton(
          icon: 'minus',
          tooltip: 'Zoom out',
          onPressed: !photo || fit || cropMode ? null : editor.zoomOut),
      SizedBox(
        width: 40,
        child: Text(fit ? 'Fit' : '${(editor.scale * 100).round()}%',
            textAlign: TextAlign.center,
            style: editorText(context,
                color: doc == null ? palette.text.withValues(alpha: .4) : palette.text)),
      ),
      QuietButton(
          icon: 'plus',
          tooltip: 'Zoom in',
          onPressed: !photo || max || cropMode ? null : editor.zoomIn),
      const SizedBox(width: Metrics.toolbarGap),
      QuietButton(
          icon: 'fit',
          tooltip: 'Zoom to fit (0)',
          onPressed: !photo || fit ? null : () => editor.setZoom(null)),
      const SizedBox(width: Metrics.toolbarGap),
      QuietButton(
        icon: 'selective',
        tooltip: 'Selective',
        selected: editor.panel == Panel.selective && editor.inspectorOpen,
        onPressed: !photo || editor.exporting || doc.isMovie ? null : () => open(Panel.selective),
      ),
      const SizedBox(width: Metrics.toolbarGap),
      QuietButton(
        icon: 'crop',
        tooltip: 'Crop',
        selected: editor.panel == Panel.crop && editor.inspectorOpen,
        onPressed: !photo || editor.exporting ? null : () => open(Panel.crop),
      ),
      // A middling window gives the readout's room to the tools.
      if (!_crowded(editor.layout.window)) PixelReadout(doc: doc),
    ]);
  }
}

bool _crowded(double? window) => window != null && window > 833 && window < 1010;

/// The histogram, history, reset, export, More and the inspector.
class _EditGroup extends StatelessWidget {
  const _EditGroup({required this.commands, this.compact = false});
  final EditorCommands commands;

  /// The compact toolbar's buttons, at touch size.
  final bool compact;

  EditorModel get editor => commands.editor;

  @override
  Widget build(BuildContext context) {
    final doc = editor.active;
    final exporting = editor.exporting;
    final history = doc?.history;
    final size = compact ? Metrics.compactTouch : Metrics.control;
    final gap = SizedBox(width: compact ? 0 : Metrics.toolbarGap);
    final histogram = QuietButton(
      icon: 'histogram',
      tooltip: 'Histogram (H)',
      selected: editor.histogramOpen,
      onPressed: doc != null ? editor.toggleHistogram : null,
    );
    // What Undo and Redo will change, as the Edit menu names it.
    final undo = QuietButton(
        icon: 'undo',
        tooltip: '${editor.history.undo} (${shortcutLabel('⌘Z')})',
        size: size,
        onPressed: (history?.past.isNotEmpty ?? false) && !exporting ? editor.undo : null);
    final redo = QuietButton(
        icon: 'redo',
        tooltip: '${editor.history.redo} (${shortcutLabel('⇧⌘Z')})',
        size: size,
        onPressed: (history?.future.isNotEmpty ?? false) && !exporting ? editor.redo : null);
    final reset = QuietButton(
        icon: 'reset',
        tooltip: 'Reset all edits',
        onPressed: doc != null && !exporting ? editor.resetEdit : null);
    // Exports running in the background (export_progress.dart).
    final progress = [
      if (editor.exporter.busy) ...[ExportProgressButton(editor: editor, size: size), gap],
    ];
    final export = QuietButton(
        icon: 'export',
        tooltip: 'Export (${shortcutLabel('⌘E')})',
        size: size,
        onPressed: doc != null && editor.stocks.isNotEmpty && !exporting
            ? commands.actions.export
            : null);
    final more = Builder(
      key: moreOptionsKey,
      builder: (anchor) => QuietButton(
        icon: 'more',
        tooltip: 'More options',
        opensMenu: true,
        size: size,
        onPressed: () => showMoreOptions(anchor, commands),
      ),
    );
    // The compact row keeps what a phone reaches for; More holds the histogram and Reset, and
    // the rail below opens the panels.
    if (compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [undo, redo, ...progress, export, more]);
    }
    return Row(children: [
      histogram,
      Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: Palette.of(context).border,
      ),
      undo,
      gap,
      redo,
      gap,
      reset,
      gap,
      ...progress,
      export,
      gap,
      more,
      gap,
      QuietButton(
        icon: 'inspector',
        tooltip: 'Toggle adjustments',
        selected: editor.inspectorOpen,
        onPressed: editor.layout.toggleInspector,
      ),
    ]);
  }
}

/// The More button, for the driver to open its menu.
final moreOptionsKey = GlobalKey(debugLabel: 'moreOptions');

/// The More menu: its sections in order, each closed by a divider.
void showMoreOptions(BuildContext anchor, EditorCommands commands) {
  final editor = commands.editor;
  final exporting = editor.exporting;
  final doc = editor.active;
  final noPhoto = doc == null || exporting;
  final imageOnlyDisabled = noPhoto || doc.isMovie;
  final auto = editor.auto;
  final presets = editor.presets;
  final steps = editor.history.timeline;
  void open(Panel panel) => editor.layout.choosePanel(panel);
  final sections = <List<MenuItem>>[
    // The three-part bar has no Add media of its own, and a phone's drawer no longer lists films,
    // so importing lives here.
    if (editor.layout.compact || mobilePlatform)
      [
        MenuItem(
          label: 'Add Photos…',
          icon: 'plus',
          onSelected: editor.ready && !exporting ? commands.actions.openGallery : null,
        ),
        MenuItem(
          label: 'From Files…',
          icon: 'folder',
          onSelected: editor.ready && !exporting ? commands.actions.openFiles : null,
        ),
        // The bar keeps three things, so Undo and Redo live here.
        MenuItem(
          label: editor.history.undo,
          icon: 'undo',
          onSelected: (doc?.history.past.isNotEmpty ?? false) && !exporting ? editor.undo : null,
        ),
        MenuItem(
          label: editor.history.redo,
          icon: 'redo',
          onSelected: (doc?.history.future.isNotEmpty ?? false) && !exporting ? editor.redo : null,
        ),
      ],
    // What the three-part bar has no room for: the histogram and Reset.
    if (editor.layout.compact || mobilePlatform)
      [
        MenuItem(
          label: 'Histogram',
          icon: 'histogram',
          selection: MenuSelection.multiple,
          checked: editor.histogramOpen,
          onSelected: doc != null ? editor.toggleHistogram : null,
        ),
        MenuItem(
          label: 'Reset All Edits',
          icon: 'reset',
          onSelected: noPhoto ? null : editor.resetEdit,
        ),
      ],
    [
      MenuItem(
        label: 'Import Scanned Negative…',
        icon: 'negative',
        onSelected: editor.negatives.canImport ? editor.negatives.chooseNegatives : null,
      ),
      if (editor.engine?.opensPaths ?? true)
        MenuItem(
          label: 'Import Trichromatic Scan…',
          icon: 'negative',
          onSelected: editor.negatives.canMerge ? editor.negatives.chooseExposures : null,
        ),
      if (editor.filmPacks.available)
        MenuItem(
          label: 'Import Film Pack…',
          icon: 'film',
          onSelected: exporting ? null : () => chooseFilmPacks(editor),
        ),
    ],
    // Automatic adjustments: a mode, ticked while it is on.
    [
      MenuItem(
        label: auto.busy
            ? 'Cancel Auto Adjust'
            : editor.catalogue.control('autoAdjustment')['title'] as String,
        icon: auto.busy ? 'close' : 'autoAdjust',
        selection: MenuSelection.multiple,
        checked: auto.active,
        onSelected: auto.available ? auto.toggle : null,
      ),
    ],
    // Every step of the shown photograph's history, the one standing ticked.
    [
      MenuItem(
        label: 'Edit History',
        icon: 'undo',
        submenu: noPhoto
            ? const []
            : [
                for (final (i, title) in steps.titles.indexed)
                  MenuItem(
                    label: title,
                    selection: MenuSelection.single,
                    checked: i == steps.index,
                    onSelected: () => editor.history.goTo(i),
                  ),
              ],
      ),
    ],
    // Paste Settings and presets go onto every photo chosen in the strip.
    [
      MenuItem(
        label: 'Copy Settings…',
        icon: 'copySettings',
        description: mobilePlatform ? null : shortcutLabel('⌥⌘C'),
        onSelected: noPhoto ? null : commands.actions.copySettings,
      ),
      MenuItem(
        label: pasteTitle(editor.selection.chosen.length),
        icon: 'pasteSettings',
        description: mobilePlatform ? null : shortcutLabel('⌥⌘V'),
        onSelected: noPhoto || presets.copied == null ? null : presets.paste,
      ),
      MenuItem(label: 'Presets', icon: 'presets', submenu: [
        for (final preset in presets.list)
          MenuItem(
              label: preset.name,
              onSelected: noPhoto ? null : () => presets.applyPreset(preset.id)),
        if (presets.list.isNotEmpty) const MenuItem.divider(),
        MenuItem(label: 'Save Preset…', onSelected: noPhoto ? null : commands.actions.savePreset),
        MenuItem(
            label: 'Manage Presets…',
            onSelected: presets.list.isEmpty ? null : commands.actions.managePresets),
        MenuItem(label: 'Import Looks…', onSelected: exporting ? null : commands.actions.importLooks),
      ]),
    ],
    [
      MenuItem(
          label: 'Save edits…',
          icon: 'saveEdits',
          onSelected: noPhoto ? null : editor.keptEdits.saveFile),
      MenuItem(
          label: 'Load edits…',
          icon: 'loadEdits',
          onSelected: noPhoto ? null : editor.keptEdits.loadFile),
    ],
    [
      MenuItem(
        label: 'Selective',
        icon: 'selective',
        onSelected: imageOnlyDisabled ? null : () => open(Panel.selective),
      ),
      MenuItem(
        label: 'Crop',
        icon: 'crop',
        onSelected: imageOnlyDisabled ? null : () => open(Panel.crop),
      ),
      MenuItem(label: 'Inspect pipeline', icon: 'pipeline', onSelected: () => open(Panel.pipeline)),
    ],
    [
      MenuItem(
        label: 'Settings…',
        icon: 'adjustments',
        onSelected: () => editor.dialogs.request(AppDialog.settings),
      ),
      if (editor.plugins.available)
        MenuItem(
          label: 'Plug-ins…',
          icon: 'export',
          onSelected: exporting ? null : () => editor.dialogs.request(AppDialog.plugins),
        ),
      if (!mobilePlatform)
        MenuItem(
          label: 'Keyboard shortcuts',
          icon: 'shortcuts',
          onSelected: () => editor.dialogs.request(AppDialog.shortcuts),
        ),
      MenuItem(
        label: 'Browser support',
        icon: 'help',
        onSelected: () => editor.dialogs.request(AppDialog.support),
      ),
    ],
    legalMenuItems(editor.catalogue),
  ];
  showMenu(anchor, alignEnd: true, width: 240, [
    for (final (i, section) in sections.where((s) => s.isNotEmpty).indexed) ...[
      if (i > 0) const MenuItem.divider(),
      ...section,
    ],
  ]);
}

/// The app's mark and name, compact. The mark is drawn rather than shipped as an asset so it takes
/// the appearance's accent and stays sharp at any size.
class LatentImageBrand extends StatelessWidget {
  const LatentImageBrand({super.key, this.size = 22, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(size: size),
      if (showName) ...[
        const SizedBox(width: 7),
        Text('Latent Image',
            style: editorText(context,
                    size: TextSizes.heading, weight: FontWeight.w500, color: palette.text)
                .copyWith(letterSpacing: .1)),
      ],
    ]);
  }
}

/// The mark alone: a rounded square, a ring inside it, and the ring's left half filled — the latent
/// image, half developed, half still in the emulsion.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22, this.color});
  final double size;

  /// The accent, unless given one.
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BrandMarkPainter(color ?? Palette.of(context).accent)),
      );
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.colour);
  final Color colour;

  // Drawn in the 24-unit box the mark was designed in.
  static const _unit = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / _unit;
    final paint = Paint()
      ..color = colour
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = colour
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1.4 * s, 1.4 * s, 21.2 * s, 21.2 * s),
        Radius.circular(6.6 * s),
      ),
      stroke,
    );
    final centre = Offset(12 * s, 12 * s);
    final ring = Rect.fromCircle(center: centre, radius: 5.4 * s);
    canvas.drawCircle(centre, 5.4 * s, stroke);
    // From the bottom, a half turn through the left side to the top.
    canvas.drawArc(ring, math.pi / 2, math.pi, true, paint);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => old.colour != colour;
}
