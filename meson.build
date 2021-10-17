project('com.github.aharotias2.aho-sudoku', 'vala', 'c', version: '0.0.1')

executable(
  'com.github.aharotias2.aho-sudoku',
  files(
    'src/sudoku.vala'
  ),
  dependencies: [
    dependency('gdk-3.0'),
    dependency('gtk+-3.0'),
    dependency('gee-0.8')
  ],
  install: true,
  install_dir: get_option('prefix') / 'bin'
)

