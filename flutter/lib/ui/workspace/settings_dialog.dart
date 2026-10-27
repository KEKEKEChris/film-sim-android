// The Mac app's Settings window: what new photographs start on, how photos export, and the film
// model. Everything here is kept on this device; open photographs keep their own edits. Video's
// settings wait for video in this editor.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';

import '../../model/app_version.dart';
import '../../model/editor.dart';
import '../../model/film_packs.dart';
import '../../model/film_suggestion.dart';
import '../../model/l10n.dart';
import '../../model/new_photo.dart';
import '../kit/kit.dart';
import '../theme/theme.dart';
import 'app_dialogs.dart';

enum SettingsPane { general, output, filmModel, about }

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.editor, required this.onClose});
  final EditorModel editor;
  final VoidCallback onClose;

  /// The pane a driver or a later opening asks for.
  static SettingsPane pane = SettingsPane.general;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SettingsPane _pane = SettingsDialog.pane;

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [editor, editor.settings, editor.filmPacks, editor.filmSuggestion]),
      builder: (context, _) => AppDialogCard(
        title: 'Settings',
        onDismiss: widget.onClose,
        children: [
          SegmentedControl<SettingsPane>(
            items: const [
              (SettingsPane.general, 'General'),
              (SettingsPane.output, 'Output'),
              (SettingsPane.filmModel, 'Film Model'),
              (SettingsPane.about, 'About'),
            ],
            selected: _pane,
            onChanged: (p) => setState(() => _pane = SettingsDialog.pane = p),
          ),
          const SizedBox(height: 8),
          ...switch (_pane) {
            SettingsPane.general => _general(context),
            SettingsPane.output => _output(),
            SettingsPane.filmModel => _filmModel(),
            SettingsPane.about => _about(),
          },
        ],
      ),
    );
  }

  AppSettings get _settings => widget.editor.settings;

  List<PickerOption<String?>> _choices(String field) => [
        for (final c in (widget.editor.catalogue.control(field)['choices'] as List).cast<Json>())
          PickerOption(c['id'] as String, c['label'] as String),
      ];

  // ── General ─────────────────────────────────────────────────────────────────────────────

  List<Widget> _general(BuildContext context) {
    final editor = widget.editor;
    final suggestion = editor.filmSuggestion;
    final learned = suggestion.learned == null || suggestion.learned! > 0;
    return [
      // The language comes first: it is the one setting that changes what every other one is
      // called, so a reader who cannot read the interface finds it before anything else.
      const PaneHeading('Language'),
      PickerField<AppLanguage>(
        label: 'Language',
        detail: 'Choose the language the editor speaks.',
        value: L10n.instance.preference,
        options: [
          for (final language in AppLanguage.values)
            PickerOption(language, L10n.instance.label(language)),
        ],
        onChanged: (language) {
          L10n.instance.setPreference(language);
        },
      ),
      const PaneNote('Follows the phone.'),
      const PaneHeading('Appearance', divider: true),
      PickerField<String>(
        label: 'Appearance',
        detail: 'Choose the colours the editor draws with.',
        value: _settings.get<String>('appearance') ?? 'warm',
        options: [
          for (final (id, name) in Palette.appearances) PickerOption(id, name),
        ],
        onChanged: (id) => _settings.set('appearance', id),
      ),
      const PaneNote('Warm darkroom is the default. Pure drops every warm tone from the chrome, '
          'which makes it easier to judge colour; neither tints the photograph.'),
      const PaneHeading('New Photos', divider: true),
      _SettingPicker(
        label: 'Starting Film',
        setting: 'startingFilm',
        settings: _settings,
        options: [
          const PickerOption(null, 'Current Film'),
          const PickerOption('none', 'Normal'),
          for (final s in editor.stocks) PickerOption(s['id'] as String, s['name'] as String),
        ],
      ),
      _SettingPicker(
        label: 'Film Format',
        setting: 'startingFormat',
        settings: _settings,
        options: [
          const PickerOption(null, 'Match the Film'),
          for (final f in editor.catalogue.filmFormats)
            PickerOption(f['id'] as String, f['name'] as String),
        ],
      ),
      if (suggestion.available) ...[
        _SettingSwitch(label: 'Suggest a Film Automatically', setting: 'autoFilm', settings: _settings),
        const PaneNote('Suggests a film when you open a photo, based on your previous choices. '
            'You can select a different film at any time.'),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: _ForgetButton(suggestion: suggestion, learned: learned),
        ),
      ],
      if (editor.filmPacks.available) _FilmPacksSection(packs: editor.filmPacks),
      if (editor.updates.available) ...[
        const PaneHeading('Updates', divider: true),
        _SettingSwitch(
            label: 'Check for Updates Automatically',
            setting: 'updateChecksAutomatically',
            settings: _settings),
        _SettingSwitch(label: 'Include Pre-releases', setting: 'updatePrereleases', settings: _settings),
      ],
      const PaneHeading('Reset', divider: true),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: PillButton('Reset All Settings',
            variant: ButtonVariant.negative, onPressed: () => _confirmReset(context)),
      ),
      const PaneNote('Restores Latent Image’s original settings. Your photographs and edits are not '
          'changed.'),
    ];
  }

  void _confirmReset(BuildContext context) {
    showModal(
      context,
      (close) => AlertCard(
        title: 'Reset All Settings?',
        message: 'This restores Latent Image’s original settings. Your photos and edits will not '
            'change.',
        primary: 'Reset',
        variant: ButtonVariant.negative,
        cancel: 'Cancel',
        onCancel: close,
        onPrimary: () {
          _settings.resetAll();
          close();
        },
      ),
    );
  }

  // ── Output ──────────────────────────────────────────────────────────────────────────────

  List<Widget> _output() {
    final current = _settings.get<String>('exportDirectoryUri') ?? _settings.get<String>('exportDirectory');
    final environmentDefault = widget.editor.exporter.fixedDirectory;
    return [
      const PaneNote('Settings are saved on this device. Existing photographs keep their own edits.'),
      const PaneHeading('Export Location'),
      InfoRow('Default folder', current == null
          ? (environmentDefault ?? 'Pictures/Latent Image')
          : (current.startsWith('content://') ? 'Selected Android folder' : current)),
      const SizedBox(height: 8),
      Row(children: [
        PillButton('Choose Default Folder', onPressed: () async {
          final path = kIsWeb
              ? null
              : defaultTargetPlatform == TargetPlatform.android
                  ? await widget.editor.exporter.chooseDefaultDirectory()
                  : await getDirectoryPath(confirmButtonText: 'Use Folder');
          if (path != null && mounted) {
            widget.editor.exporter.defaultDirectory = path;
          }
        }),
        const SizedBox(width: 8),
        PillButton('Use Platform Default', onPressed: current == null ? null : () {
          _settings.set('exportDirectoryUri', null);
          widget.editor.exporter.defaultDirectory = null;
        }),
      ]),
      const PaneNote('Exports use this folder without asking each time. On Android the platform '
          'default is Pictures/Latent Image; choosing a folder is available on systems that provide '
          'a folder picker.'),
      ..._outputBody(),
    ];
  }

  List<Widget> _outputBody() {
    final exports =
        ((widget.editor.engine?.capabilities['imageExportTypes'] as List?) ?? const []).isNotEmpty;
    if (!exports) {
      return [
        const PaneHeading('Photos'),
        const PaneNote('This engine exports photos in standard dynamic range.'),
        ..._video(),
      ];
    }
    return [
      const PaneHeading('Photos'),
      const SizedBox(height: 4),
      _SettingSwitch(label: 'HDR', setting: 'photoHDR', settings: _settings),
      const PaneNote('HDR preserves brighter highlights on compatible displays. Choose Standard '
          'for wider compatibility. It applies to HEIC exports of films that deliver HDR, '
          'without a print frame.'),
      _SettingPicker(
        label: 'Photo Quality',
        setting: 'photoQuality',
        settings: _settings,
        options: const [PickerOption('accurate', 'Accurate'), PickerOption('fast', 'Fast')],
      ),
      const PaneNote('Accurate uses exact film curves. Fast uses an approximation to reduce '
          'processing time.'),
      ..._video(),
    ];
  }

  /// Video Quality, HDR and Video File Size where the engine's platform offers them, and the
  /// transport's Playback Quality where it plays movies.
  List<Widget> _video() {
    final exporter = widget.editor.exporter;
    final playable = widget.editor.engine?.capabilities['video'] == true;
    final hdr = exporter.videoTypes.any((t) => t['hdr'] == true);
    final bitrates = exporter.videoBitrates;
    if (!playable) return const [];
    return [
      const PaneHeading('Video', divider: true),
      _SettingPicker(
        label: 'Playback Quality',
        setting: 'videoPlaybackQuality',
        settings: _settings,
        options: [for (final (id, name, _) in playbackQualities) PickerOption(id, name)],
      ),
      const PaneNote(playbackQualityHelp),
      if (exporter.videoProcessingOffered) ...[
        _SettingPicker(
          label: 'Video Quality',
          setting: 'videoProcessing',
          settings: _settings,
          options: const [PickerOption('full', 'Full'), PickerOption('fast', 'Fast')],
        ),
        const PaneNote('Video quality sets the processing resolution. Full uses the source '
            'resolution; Fast processes at up to 1080p.'),
      ],
      if (hdr) ...[
        _SettingSwitch(label: 'HDR', setting: 'videoHDR', settings: _settings),
        const PaneNote('HEVC and ProRes movies of films that deliver HDR are written as HLG; '
            'H.264 stays standard.'),
      ],
      if (bitrates.isNotEmpty) ...[
        _SettingPicker(
          label: 'Video File Size',
          setting: 'videoBitrate',
          settings: _settings,
          options: [
            for (final b in bitrates) PickerOption(b['id'] as String, b['label'] as String),
          ],
        ),
        const PaneNote('Automatic lets the encoder choose. ProRes keeps its own rate.'),
      ],
    ];
  }

  // ── About ────────────────────────────────────────────────────────────────────────────────

  List<Widget> _about() => [
        const PaneHeading('Current Version'),
        InfoRow('Version', AppVersion.name),
        InfoRow('Build', AppVersion.build),
        const PaneNote('The build number increases with every Android package so upgrades install '
            'over the previous version.'),
        const PaneHeading('Upgrade History', divider: true),
        for (final release in AppVersion.history) ...[
          Text('${release.version} · ${t(release.title)}',
              style: editorText(context, weight: FontWeight.w700)),
          for (final change in release.changes)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('• ${t(change)}', style: editorText(context, color: Palette.of(context).muted)),
            ),
          const SizedBox(height: 10),
        ],
      ];

  // ── Film Model ──────────────────────────────────────────────────────────────────────────

  /// The Mac app reads halation as a photo develops, so those settings reach the open photo.
  bool get _modelled => widget.editor.active != null && widget.editor.edit['stock'] != null;

  List<Widget> _filmModel() {
    final editor = widget.editor;
    String title(String field) => editor.catalogue.control(field)['title'] as String;
    return [
      const PaneHeading('Grain'),
      _SettingPicker(
        label: title('grainModel'),
        setting: 'grainModel',
        settings: _settings,
        options: _choices('grainModel'),
      ),
      const PaneNote('Standard uses fast calibrated RMS noise, and Film lays the stock’s crystals '
          'at fixed places on the emulsion.'),
      const PaneHeading('Halation', divider: true),
      _SettingPicker(
        label: title('halationModel'),
        setting: 'halationModel',
        settings: _settings,
        options: _choices('halationModel'),
        onSet: (model) {
          if (_modelled) editor.change({'halationModel': model});
        },
      ),
      _SettingSwitch(
        label: title('estimatedHalation'),
        setting: 'estimatedHalation',
        settings: _settings,
        onSet: (on) {
          if (_modelled) editor.setProfile('estimatedHalation', on, grouped: false);
        },
      ),
      const PaneNote('Layered Transport simulates light moving through the film layers. In the '
          'browser, films with donor layers use Legacy. Estimated Halation Shape only affects '
          'Legacy.'),
      const PaneHeading('Color Separation', divider: true),
      _SettingSlider(label: title('couplerReach'), setting: 'couplerReach', settings: _settings),
      _SettingSlider(
          label: 'Red–Green', setting: 'couplerRedGreen', follows: 'couplerReach', settings: _settings),
      _SettingSlider(
          label: 'Green–Blue', setting: 'couplerGreenBlue', follows: 'couplerReach', settings: _settings),
      _SettingSlider(label: title('couplerSelf'), setting: 'couplerSelf', settings: _settings),
      const PaneNote('Separation sets how strongly neighboring film layers affect each other '
          'during development, for both color pairs together. Red–Green and Green–Blue adjust '
          'each pair separately. Edge Contrast controls sharpening caused by development.'),
      const PaneNote('Halation settings also change the open photo. The others apply to photos '
          'you open from now on; each open photo keeps its own.'),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: PillButton(
          'Restore Film Model',
          variant: ButtonVariant.negative,
          onPressed: filmModelAdjusted(_settings)
              ? () {
                  for (final key in filmModelSettings) {
                    _settings.set(key, AppSettings.defaults[key]);
                  }
                }
              : null,
        ),
      ),
    ];
  }
}

/// A picker for a setting; null is its default choice. `onSet` also runs with each new value, for
/// a setting the open photo follows.
class _SettingPicker extends StatelessWidget {
  const _SettingPicker({
    required this.label,
    required this.setting,
    required this.settings,
    required this.options,
    this.onSet,
  });

  final String label, setting;
  final AppSettings settings;
  final List<PickerOption<String?>> options;
  final ValueChanged<String?>? onSet;

  @override
  Widget build(BuildContext context) {
    final value = settings.get<Object>(setting);
    // The label goes above the picker rather than beside it: a fixed-width picker in a row left
    // the name a few pixels wide on a phone, which wrapped it one letter a line.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: PickerField<String?>(
        label: label,
        value: value is String ? value : null,
        options: options,
        onChanged: (next) {
          settings.set(setting, next);
          onSet?.call(next);
        },
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch(
      {required this.label, required this.setting, required this.settings, this.onSet});
  final String label, setting;
  final AppSettings settings;
  final ValueChanged<bool>? onSet;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SwitchRow(
          label: label,
          value: settings.get(setting) == true,
          onChanged: (next) {
            settings.set(setting, next);
            onSet?.call(next);
          },
        ),
      );
}

/// A slider from 0 to 3 in tenths. `follows`: the setting shown while this one has never been set
/// on its own.
class _SettingSlider extends StatelessWidget {
  const _SettingSlider(
      {required this.label, required this.setting, required this.settings, this.follows});
  final String label, setting;
  final String? follows;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final own = settings.get<num>(setting);
    final followed = settings.get<num>(follows ?? setting);
    final value = (own ?? followed ?? 1).toDouble();
    final rest = (AppSettings.defaults[setting] as num?) ?? followed ?? 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AdjustmentRow(
        label: label,
        value: value,
        range: SliderRange(min: 0, max: 3, step: .1, def: rest.toDouble()),
        onChanged: (next) => settings.set(setting, (next * 10).round() / 10),
      ),
    );
  }
}

/// Reset Film Suggestions: greyed with nothing learned, as the Mac app's is.
class _ForgetButton extends StatefulWidget {
  const _ForgetButton({required this.suggestion, required this.learned});
  final FilmSuggestion suggestion;
  final bool learned;

  @override
  State<_ForgetButton> createState() => _ForgetButtonState();
}

class _ForgetButtonState extends State<_ForgetButton> {
  bool _forgotten = false;

  @override
  void initState() {
    super.initState();
    widget.suggestion.refresh();
  }

  @override
  Widget build(BuildContext context) => PillButton(
        _forgotten ? 'Film Suggestions Reset' : 'Reset Film Suggestions',
        onPressed: _forgotten || !widget.learned
            ? null
            : () => widget.suggestion.forget().then((_) {
                  if (mounted) setState(() => _forgotten = true);
                }).ignore(),
      );
}

/// The community packs installed where this person's films live: add more, or take one away with
/// its films.
class _FilmPacksSection extends StatefulWidget {
  const _FilmPacksSection({required this.packs});
  final FilmPacks packs;

  @override
  State<_FilmPacksSection> createState() => _FilmPacksSectionState();
}

class _FilmPacksSectionState extends State<_FilmPacksSection> {
  String? _notice;
  bool _busy = false;

  FilmPacks get packs => widget.packs;

  @override
  void initState() {
    super.initState();
    // Read afresh each time: another app may have added one since.
    packs.refresh().ignore();
  }

  Future<void> _run(Future<String?> Function() work, String failure) async {
    setState(() => _busy = true);
    String? notice;
    try {
      notice = await work();
    } catch (e) {
      notice = '$failure — $e';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _notice = notice;
      });
    }
  }

  Future<void> _import() => _run(() async {
        final files = await openFiles(acceptedTypeGroups: const [
          XTypeGroup(label: 'Film packs', extensions: [filmPackExtension]),
        ]);
        if (files.isEmpty) return _notice;
        final notice = PackNotice.of(
            await packs.importPaths([for (final f in files) f.path], quiet: true));
        return '${notice.title} — ${notice.message}';
      }, 'Pack not added');

  @override
  Widget build(BuildContext context) {
    final installed = packs.installed ?? const [];
    final disabled = _busy || packs.editor.exporting || packs.editor.exporter.busy;
    final muted = editorText(context, size: TextSizes.label, color: Palette.of(context).muted);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PaneHeading('Film Packs'),
      if (installed.isEmpty)
        const PaneNote('No film packs are installed.')
      else
        for (final pack in installed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pack['version'] != null ? '${pack['name']} v${pack['version']}' : '${pack['name']}'),
                  Text(
                    pack['problem'] as String? ??
                        ((pack['films'] as List?) ?? const []).join(', '),
                    style: muted,
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              PillButton('Remove',
                  onPressed: disabled
                      ? null
                      : () => _run(() async {
                            await packs.remove(pack['packID'] as String);
                            return null;
                          }, 'Pack not removed')),
            ]),
          ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: PillButton('Import Film Pack…', onPressed: disabled ? null : _import),
      ),
      if (_notice != null) PaneNote(_notice!),
    ]);
  }
}
