damask_blueprints = [
  'preferences.blp',
  'shortcuts.blp',
  'sources/apod.blp',
  'sources/bing.blp',
  'sources/manual.blp',
  'sources/wallhaven.blp',
  'window.blp'
]

blueprints = custom_target('blueprints',
  input: damask_blueprints,
  output: '.',
  command: [find_program('blueprint-compiler'),
              'batch-compile',
              '@OUTDIR@',
              '@CURRENT_SOURCE_DIR@',
              '@INPUT@']
)

damask_sources = [
  'application.vala',
  'main.vala',
  'preferences.vala',
  'sources/apod.vala',
  'sources/bing.vala',
  'sources/manual.vala',
  'sources/wallhaven.vala',
  'wallpaper-source.vala',
  'window.vala',
]

# This "target" creates a stamp file that is newer than src/meson.build. This
# appears to ensure that the blueprint files are compiled into UI XML definition
# files. Otherwise, if the file src/meson.build is newer than the blueprint
# files, they won't get compiled.
damask_sources += custom_target('blueprints_stamp',
  input: blueprints,
  output: 'blueprint.vala',
  command: [find_program('touch'), '@OUTPUT@'],
)

damask_sources += configure_file(
  input: 'constants.vala.in',
  output: 'constants.vala',
  configuration: config_data
)

damask_deps = [
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>=1.2.0'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('libportal'),
  dependency('libportal-gtk4'),
]

damask_sources += gnome.compile_resources('damask-resources',
  configure_file(
    input: '@0@.gresource.xml.in'.format(meson.project_name()),
    output: '@0@.gresource.xml'.format(meson.project_name()),
    configuration: config_data
  ),
  dependencies: blueprints,
  c_name: 'damask',
  source_dir: meson.current_build_dir()
)

executable('damask', damask_sources,
  dependencies: damask_deps,
       install: true,
     vala_args: ['--gresourcesdir=' + blueprints.full_path()]
)
