project('damask', ['c', 'vala'],
          version: '0.3.1',
    meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2', 'werror=false', ],
)

app_id_prefix = 'app.drey.Damask'
app_id = app_id_prefix
resource_path_prefix = '/app/drey/Damask'
resource_path = resource_path_prefix

app_id_suffix = ''
resource_path_suffix = ''
if get_option('development') == true
  app_id += '.Devel'
  resource_path += '/Devel'
endif

i18n = import('i18n')
gnome = import('gnome')

add_project_arguments(['-DGETTEXT_PACKAGE="damask"', '-DG_LOG_DOMAIN="damask"'], language: 'c')

config_data = configuration_data()
config_data.set('VERSION', meson.project_version())
config_data.set('APP_ID', app_id)
config_data.set('RESOURCE_PATH_PREFIX', resource_path_prefix)
config_data.set('RESOURCE_PATH', resource_path)
config_data.set('GETTEXT_PACKAGE', meson.project_name ())
config_data.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set('UNSPLASH_ACCESS_KEY', get_option('unsplash_access_key'))
config_data.set('NASA_API_KEY', get_option('nasa_api_key'))

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
     glib_compile_schemas: true,
    gtk_update_icon_cache: true,
  update_desktop_database: true,
)
