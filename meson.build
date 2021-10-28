project('com.github.aharotias2.aho-sudoku', 'vala', 'c', version: '0.0.1')

executable(
  'com.github.aharotias2.aho-sudoku',
  files(
    'src/sudoku.vala'
  ),
  dependencies: [
    dependency('gdk-3.0'),
    dependency('gtk+-3.0')
  ],
  install: true,
  install_dir: get_option('prefix') / 'bin'
)

install_data(
  'data/com.github.aharotias2.aho-sudoku.png',
  install_dir: get_option('datadir') / 'share/icons/hicolor/256x256/apps'
)

install_data(
  'data/com.github.aharotias2.aho-sudoku.desktop',
  install_dir: get_option('datadir') / 'applications'
)

