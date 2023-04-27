desktop_file = i18n.merge_file(
        input: configure_file(
	    input: 'app.drey.Damask.desktop.in.in',
	    output: '@0@.desktop.in'.format(app_id),
	    configuration: config_data
	  ),
       output: '@0@.desktop'.format(app_id),
         type: 'desktop',
       po_dir: '../po',
      install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

appstream_file = i18n.merge_file(
        input: configure_file(
              input: 'app.drey.Damask.metainfo.xml.in.in',
              output: '@0@.metainfo.xml.in'.format(app_id),
              configuration: config_data
          ),
       output: '@0@.metainfo.xml'.format(app_id),
       po_dir: '../po',
      install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util, args: ['--nonet', 'validate-relax', appstream_file])
endif

install_data(configure_file(
    input: 'app.drey.Damask.gschema.xml.in',
    output: '@0@.gschema.xml'.format(app_id),
    configuration: config_data
  ),
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file',
       compile_schemas,
       args: ['--strict', '--dry-run', meson.current_source_dir()])
endif

subdir('icons')
