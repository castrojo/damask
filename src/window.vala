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
        private ListStore source_store = new ListStore (typeof(WallpaperSource));

        public Window (Gtk.Application app) {
            Object (application: app);

            this.application.set_accels_for_action ("win.show-help-overlay", {"<primary>question"});

            if (Constants.APP_ID.contains (".Devel")) {
                this.add_css_class ("devel");
            }

            foreach (WallpaperSource src in (app as Application).sources.values) {
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
                    var prefs_window = new Adw.PreferencesWindow ();
                    prefs_window.set_search_enabled (false);
                    var prefs = wp_source.prefs ();
                    if (prefs != null) {
                        prefs_window.add (prefs);
                    }
                    prefs_window.set_transient_for (this);
                    prefs_window.present ();
                });
                row.add_suffix (prefs_button);

                Gtk.CheckButton button = new Gtk.CheckButton ();
                button.group = this.active_source;

                if (Application.settings.get_string("active-source") == row.title) {
                    button.set_active (true);
                }

                button.toggled.connect ((button) => {
                    Application.settings.set_string("active-source", row.title);
                });
                row.add_prefix (button);
                row.set_activatable_widget (button);

                return row;
            });

            Gtk.Builder builder = new Gtk.Builder.from_resource (@"$(Constants.RESOURCE_PATH_PREFIX)/shortcuts.ui");
            Gtk.ShortcutsWindow help_overlay = builder.get_object ("help_overlay") as Gtk.ShortcutsWindow;
            this.set_help_overlay (help_overlay);
        }
    }
}
