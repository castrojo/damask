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
        [GtkChild] private unowned Gtk.ListBox sources;
        [GtkChild] private unowned Gtk.CheckButton active_source;

        [GtkChild] private unowned Gtk.Picture preview_picture1;
        [GtkChild] private unowned Gtk.Picture preview_picture2;
        [GtkChild] private unowned Gtk.Stack preview_stack;
        [GtkChild] private unowned Gtk.Label description_label;
        [GtkChild] private unowned Gtk.Label title_label;
        [GtkChild] private unowned Gtk.Spinner spinner;

        private ListStore source_store = new ListStore (typeof(WallpaperSource));

        public Window (Gtk.Application app) {
            Object (application: app);

            ActionEntry[] action_entries = {
                { "open-url", this.on_open_url_action },
            };
            this.add_action_entries (action_entries, this);
            this.application.set_accels_for_action ("win.show-help-overlay", {"<primary>question"});

            if (Constants.APP_ID.contains (".Devel")) {
                this.add_css_class ("devel");
            }

            Application application = app as Application;
            foreach (WallpaperSource src in application.source_list) {
                this.source_store.append (src);
            }

            this.sources.bind_model (this.source_store, (item) => {
                WallpaperSource wp_source = item as WallpaperSource;
                Adw.ActionRow row = new Adw.ActionRow ();
                row.title = wp_source.title;
                row.subtitle = wp_source.subtitle;

                Gtk.Button prefs_button = new Gtk.Button.from_icon_name ("applications-system-symbolic");
                prefs_button.valign = Gtk.Align.CENTER;
                prefs_button.clicked.connect ((button) => {
                    var prefs_window = wp_source.preferences ();
                    prefs_window.set_transient_for (this);
                    prefs_window.present ();
                });
                prefs_button.sensitive = wp_source.preferences () != null;
                row.add_suffix (prefs_button);

                Gtk.CheckButton button = new Gtk.CheckButton ();
                button.group = this.active_source;

                if (application.settings.get_string("active-source") == wp_source.id) {
                    button.set_active (true);
                }

                button.toggled.connect ((button) => {
                    application.settings.set_string("active-source", wp_source.id);
                });
                row.add_prefix (button);
                row.set_activatable_widget (button);

                return row;
            });

            Gtk.Builder builder = new Gtk.Builder.from_resource (@"$(Constants.RESOURCE_PATH_PREFIX)/shortcuts.ui");
            Gtk.ShortcutsWindow help_overlay = builder.get_object ("help_overlay") as Gtk.ShortcutsWindow;
            this.set_help_overlay (help_overlay);

            application.notify["current-wallpaper"].connect ((src, pspec) => {
                debug(@"application notify current-wallpaper");
                Soup.Session session = new Soup.Session ();
                Soup.Message msg = new Soup.Message ("GET", application.current_wallpaper.thumbnail_url);
                this.spinner.spinning = true;
                this.spinner.visible = true;
                session.send_and_read_async.begin (msg, 0, null, (src, res) => {
                    try {
                        Bytes body = session.send_and_read_async.end (res);
                        Gdk.Texture texture = Gdk.Texture.from_bytes (body);
                        if (this.preview_stack.get_visible_child () == this.preview_picture1) {
                            this.preview_picture2.paintable = texture;
                            this.preview_stack.set_visible_child (this.preview_picture2 as Gtk.Widget);
                        } else {
                            this.preview_picture1.paintable = texture;
                            this.preview_stack.set_visible_child (this.preview_picture1 as Gtk.Widget);
                        }
                        this.spinner.spinning = false;
                        this.spinner.visible = false;
                    } catch (Error e) {
                        error (e.message);
                    }
                });

                this.title_label.visible = application.current_wallpaper.title != null;
                if (application.current_wallpaper.title != null) {
                    this.title_label.set_text (application.current_wallpaper.title);
                }

                this.description_label.visible = application.current_wallpaper.description != null;
                if (application.current_wallpaper.description != null) {
                    this.description_label.set_text (application.current_wallpaper.description);
                }
            });
        }

        private void on_open_url_action () {
            Application app = this.application as Application;
            Gtk.show_uri (null, app.current_wallpaper.web_url, Gdk.CURRENT_TIME);
        }
    }
}
