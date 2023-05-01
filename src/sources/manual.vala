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
            if (path != "") {
                this._current_wallpaper = new Damask.Wallpaper () {
                    url = path,
                    thumbnail_url = path,
                    web_url = path
                };
            }
            this.settings.changed["picture-uri"].connect ((key) => {
                this.refresh ();
            });
        }

        public string id {
            get { return "manual"; }
        }

        private Damask.Wallpaper? _current_wallpaper;
        public unowned Damask.Wallpaper? current_wallpaper {
            get { return _current_wallpaper; }
        }

        public void refresh () {
            string path = this.settings.get_string ("picture-uri");
            if (path != "") {
                this._current_wallpaper = new Damask.Wallpaper () {
                    url = path,
                    thumbnail_url = path,
                    web_url = path
                };
                this.changed (path);
            }
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/manual.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.manual");

        [GtkChild] private unowned Gtk.Button choose_button;
        [GtkChild] private unowned Adw.ActionRow row;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            choose_button.clicked.connect (() => {
                Gtk.FileChooserNative chooser = new Gtk.FileChooserNative (_("Select Picture"),
                                                                           null,
                                                                           Gtk.FileChooserAction.OPEN,
                                                                           _("_Select"),
                                                                           _("_Cancel"));
                chooser.response.connect ((response) => {
                    if (response == Gtk.ResponseType.ACCEPT) {
                        File file = chooser.get_file ();
                        this.settings.set_string ("picture-uri", file.get_uri ());
                        this.row.subtitle = file.get_path ();
                    }
                });
                chooser.show ();
            });

            File file = File.new_for_uri (this.settings.get_string ("picture-uri"));
            this.row.subtitle = file.get_path ();
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
