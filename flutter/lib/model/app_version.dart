/// Version information shown in Settings. CI supplies the build's version and number so every
/// Android package can replace the preceding one; the defaults keep local and test builds useful.
abstract final class AppVersion {
  static const name = String.fromEnvironment('APP_VERSION', defaultValue: '1.14.1');
  static const build = String.fromEnvironment('APP_BUILD', defaultValue: '2000');

  /// Release notes kept with the app so Settings can explain what changed in each upgrade.
  static const history = <({String version, String title, List<String> changes})>[
    (
      version: '1.14.4',
      title: 'A bar of three things, and films that float',
      changes: [
        'The mark is drawn in the appearance\'s own accent — amber in the warm darkroom, blue in Pure — '
            'and the launcher icon is the same mark on the warm page.',
        'On a phone the bar keeps three things: back, the film over the file name, and Export. Add media, '
            'Undo and Redo move into More.',
        'The films float over the foot of the canvas instead of taking a dock\'s height, and fade away as a '
            'drawer opens, so the photograph has the whole screen.',
        'A fitted photograph touches both ends of its room on a phone, with no band of black around it.',
        'The splash is the warm page rather than white.',
        'Every build is signed with one key, so it can be installed over the one before it.',
      ],
    ),    (
      version: '1.14.3',
      title: 'Warm darkroom and pure appearances',
      changes: [
        'The editor draws in a warm darkroom by default; Settings offers a pure black and electric blue alternative.',
        'The film rail and the darkroom panel are narrower, leaving the photograph more room on a tablet.',
        'The compact rail gains a Presets button at its leading edge.',
      ],
    ),
    (
      version: '1.14.2',
      title: 'Gallery picker and export workflow',
      changes: [
        'Direct system photo picker and gallery access for choosing photos and videos.',
        'Custom export folder selection and Latent Image default folder.',
        'Real-time export progress, path display, and sharing to all apps.',
        'Soft keyboard avoidance for search bar and preset dialogs.',
        'Automatic build version increment for direct upgrade installation.',
      ],
    ),
    (
      version: '1.14.1',
      title: 'Latent Image Android improvements',
      changes: [
        'Video files can be selected from the system picker and imported.',
        'Exports show their destination and progress, can use a configurable folder, and can be shared.',
        'Search fields and the Save Preset dialog remain visible above the keyboard.',
        'The app identity is Latent Image and this Settings page records the release changes.',
      ],
    ),
  ];
}
