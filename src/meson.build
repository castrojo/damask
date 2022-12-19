damask_blueprints = [
  'info-window.blp',
  'preferences.blp',
  'sources/bing.blp',
  'sources/wallhaven.blp',
  'window.blp'
]

blueprints = custom_target('blueprints',
  input: damask_blueprints,
  output: '.',
  command: [find_program('blueprint-compiler'),
              'batch-compile',
              '@OUTPUT@',
              '@CURRENT_SOURCE_DIR@',
              '@INPUT@']
)

damask_sources = [
  'application.vala',
  'info-window.vala',
  'main.vala',
  'preferences.vala',
  'sources/bing.vala',
  'sources/manual.vala',
  'sources/wallhaven.vala',
  'wallpaper-source.vala',
  'window.vala',
]

damask_deps = [
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('libportal'),
  dependency('libportal-gtk4'),
]

damask_sources += gnome.compile_resources('damask-resources',
  'damask.gresource.xml',
  dependencies: blueprints,
  c_name: 'damask'
)

executable('damask', damask_sources,
  dependencies: damask_deps,
       install: true,
     vala_args: ['--gresourcesdir=' + blueprints.full_path(),]
)
