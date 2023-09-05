/* manual.vala
 *
 * Copyright 2022 Link Dupont <link@sub-pop.net>
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

namespace Damask.Sources.Manual {
    public class Manual : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.manual");

        construct {
            string path = this.settings.get_string ("picture-uri");
            this.settings.changed["picture-uri"].connect ((key) => {
                this.request_refresh ();
                this.refresh.begin ();
            });
        }

        public string id {
            get { return "manual"; }
        }

        public string title {
            get { return _("Manual"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            string path = this.settings.get_string ("picture-uri");
            if (path == "") {
                return null;
            }

            this.current_wallpaper = new Damask.Wallpaper () {
                url = path,
                thumbnail_url = path,
                web_url = path,
            };
            return this.current_wallpaper;
        }

        public Adw.PreferencesPage? preferences () {
            return new PreferencesPage () as Adw.PreferencesPage;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/manual.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.manual");

        [GtkChild] private unowned Gtk.Button choose_button;
        [GtkChild] private unowned Adw.ActionRow row;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            this.choose_button.clicked.connect (this.on_select_picture);

            File file = File.new_for_uri (this.settings.get_string ("picture-uri"));
            this.row.subtitle = file.get_path ();
        }

        private async void on_select_picture () {
            Gtk.FileDialog dialog = new Gtk.FileDialog ();
            dialog.title = _("Select Picture");
            try {
                File file = yield dialog.open (null, null);
                this.settings.set_string ("picture-uri", file.get_uri ());
                this.row.subtitle = file.get_path ();
            } catch (Error e) {
                message (e.message);
            }
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
