/* window.vala
 *
 * Copyright 2022 Link Dupont
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Damask {
    [GtkTemplate (ui = "/app/drey/Damask/window.ui")]
    public class Window : Adw.ApplicationWindow {
        [GtkChild] private unowned Gtk.Button refresh_button;
        [GtkChild] private unowned Gtk.Stack refresh_button_stack;
        [GtkChild] private unowned Gtk.ListBox sources;
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] private unowned Adw.PreferencesRow manual_row;
        [GtkChild] private unowned Adw.PreferencesRow slideshow_row;
        [GtkChild] private unowned Adw.PreferencesRow bing_row;
        [GtkChild] private unowned Adw.PreferencesRow wallhaven_row;
        [GtkChild] private unowned Adw.PreferencesRow apod_row;
        [GtkChild] private unowned Adw.PreferencesRow unsplash_row;
        [GtkChild] private unowned Adw.NavigationSplitView split_view;
        [GtkChild] private unowned Adw.NavigationPage source_navigation_page;

        public Window (Gtk.Application app) {
            Type? type = typeof (WallpaperPreview);
            type.ensure ();
            Object (application: app);
        }

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            Application application = GLib.Application.get_default () as Application;
            ActionEntry[] action_entries = {
                { "open-url", this.on_open_url_action },
                { "show-toast", this.on_show_toast_action },
            };
            this.add_action_entries (action_entries, this);
            application.set_accels_for_action ("win.show-help-overlay", {"<primary>question"});
            Action active_source_action = application.settings.create_action ("active-source");
            this.add_action (active_source_action);

            if (Constants.APP_ID.contains (".Devel")) {
                this.add_css_class ("devel");
            }

            Adw.PreferencesRow? row = null;
            switch (application.settings.get_string ("active-source")) {
                case "manual":
                    row = this.manual_row;
                    break;
                case "slideshow":
                    row = this.slideshow_row;
                    break;
                case "bing":
                    row = this.bing_row;
                    break;
                case "wallhaven":
                    row = this.wallhaven_row;
                    break;
                case "apod":
                    row = this.apod_row;
                    break;
                case "unsplash":
                    row = this.unsplash_row;
                    break;
                default:
                    row = this.manual_row;
                    break;
            }
            this.sources.select_row (row);
            var toolbar = this.source_navigation_page.child as Adw.ToolbarView;
            this.source_navigation_page.title = @"$(row.title) Preferences";

            switch (row.name) {
            case "manual":
                toolbar.content = new Sources.Manual.PreferencesPage ();
                break;
            case "slideshow":
                toolbar.content = new Sources.Slideshow.PreferencesPage ();
                break;
            case "bing":
                toolbar.content = new Sources.Bing.PreferencesPage ();
                break;
            case "wallhaven":
                toolbar.content = new Sources.Wallhaven.PreferencesPage ();
                break;
            case "apod":
                toolbar.content = new Sources.Apod.PreferencesPage ();
                break;
            case "unsplash":
                toolbar.content = new Sources.Unsplash.PreferencesPage ();
                break;
            default:
                toolbar.content = new Sources.Manual.PreferencesPage ();
                break;
            }

            Gtk.Builder builder = new Gtk.Builder.from_resource (@"$(Constants.RESOURCE_PATH_PREFIX)/shortcuts.ui");
            Gtk.ShortcutsWindow help_overlay = builder.get_object ("help_overlay") as Gtk.ShortcutsWindow;
            this.set_help_overlay (help_overlay);

            application.notify["is-refreshing"].connect (this.update_refresh_button);
            this.update_refresh_button ();
        }

        [GtkCallback]
        private void on_source_list_activated (Gtk.ListBox box, Gtk.ListBoxRow row) {
            debug (@"[%p] $(this.get_type().name()).on_source_list_activated", this);
            Application application = GLib.Application.get_default () as Application;
            if (row != null && row.name != application.settings.get_string ("active-source")) {
                var action_row = row as Adw.PreferencesRow;
                application.settings.set_string ("active-source", action_row.name);
                var toolbar = this.source_navigation_page.child as Adw.ToolbarView;
                this.source_navigation_page.title = @"$(action_row.title) Preferences";

                switch (action_row.name) {
                case "manual":
                    toolbar.content = new Sources.Manual.PreferencesPage ();
                    break;
                case "slideshow":
                    toolbar.content = new Sources.Slideshow.PreferencesPage ();
                    break;
                case "bing":
                    toolbar.content = new Sources.Bing.PreferencesPage ();
                    break;
                case "wallhaven":
                    toolbar.content = new Sources.Wallhaven.PreferencesPage ();
                    break;
                case "apod":
                    toolbar.content = new Sources.Apod.PreferencesPage ();
                    break;
                case "unsplash":
                    toolbar.content = new Sources.Unsplash.PreferencesPage ();
                    break;
                default:
                    toolbar.content = new Sources.Manual.PreferencesPage ();
                    break;
                }
            }
            this.split_view.show_content = true;
        }

        private void update_refresh_button () {
            Application application = GLib.Application.get_default () as Application;
            this.refresh_button_stack.visible_child_name = application.is_refreshing ? "spinner" : "sensitive";
            this.refresh_button.sensitive = !application.is_refreshing;
        }

        private void on_open_url_action () {
            Application application = GLib.Application.get_default () as Application;
            try {
                Uri uri = Uri.parse (application.current_wallpaper.web_url, UriFlags.NONE);

                switch (uri.get_scheme ()) {
                    case "file":
                        File file = File.new_for_uri (uri.to_string ());
                        Gtk.FileLauncher launcher = new Gtk.FileLauncher (file);
                        launcher.launch.begin (this, null);
                        break;
                    default:
                        Gtk.UriLauncher launcher = new Gtk.UriLauncher (uri.to_string ());
                        launcher.launch.begin (this, null);
                        break;
                }
            } catch (Error e) {
                var toast = new Adw.Toast (_("Unable to open URL: %s").printf(e.message));
                this.toast_overlay.add_toast (toast);
                message (e.message);
            }
        }

        private void on_show_toast_action (SimpleAction action, Variant? parameter) {
            var message = parameter.get_string ();
            var toast = new Adw.Toast (message);
            this.toast_overlay.add_toast (toast);
        }

        ~Window () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
