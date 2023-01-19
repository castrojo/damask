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
            this._current_wallpaper = new Damask.Wallpaper () {
                url = path,
                thumbnail_url = path,
                web_url = path
            };
            this.settings.changed["picture-uri"].connect ((key) => {
                this.refresh ();
            });
        }

        public string id {
            get { return "manual"; }
        }

        public string title {
            get { return "Manual"; }
        }

        public string subtitle {
            get { return "Manually set wallpaper"; }
        }

        private Damask.Wallpaper? _current_wallpaper;
        public unowned Damask.Wallpaper? current_wallpaper {
            get { return _current_wallpaper; }
        }

        public void refresh () {
            string path = this.settings.get_string ("picture-uri");
            this._current_wallpaper = new Damask.Wallpaper () {
                url = path,
                thumbnail_url = path,
                web_url = path
            };

            this.changed (path);
        }

        public Adw.PreferencesWindow? preferences () {
            return new PreferencesWindow () as Adw.PreferencesWindow;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/manual.ui")]
    public class PreferencesWindow : Adw.PreferencesWindow {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.manual");

        [GtkChild] private unowned Gtk.Stack preview_stack;
        [GtkChild] private unowned Gtk.Picture preview_picture1;
        [GtkChild] private unowned Gtk.Picture preview_picture2;
        [GtkChild] private unowned Gtk.Spinner spinner;
        [GtkChild] private unowned Gtk.Button choose_button;

        construct {
            try {
                File file = File.new_for_uri (this.settings.get_string ("picture-uri"));
                Gdk.Texture texture = Gdk.Texture.from_file (file);
                this.preview_picture1.paintable = texture;
                this.preview_stack.set_visible_child (this.preview_picture1 as Gtk.Widget);
                this.spinner.spinning = false;
                this.spinner.visible = false;
            } catch (Error e) {
                warning (e.message);
            }

            choose_button.clicked.connect (() => {
                Gtk.FileChooserNative chooser = new Gtk.FileChooserNative ("Select Picture",
                                                                           this,
                                                                           Gtk.FileChooserAction.OPEN,
                                                                           "_Select",
                                                                           "_Cancel");
                chooser.response.connect ((response) => {
                    this.spinner.spinning = true;
                    this.spinner.visible = true;
                    if (response == Gtk.ResponseType.ACCEPT) {
                        try {
                            File file = chooser.get_file ();
                            Gdk.Texture texture = Gdk.Texture.from_file (file);
                            if (this.preview_stack.get_visible_child () == this.preview_picture1) {
                                this.preview_picture2.paintable = texture;
                                this.preview_stack.set_visible_child (this.preview_picture2 as Gtk.Widget);
                            } else {
                                this.preview_picture1.paintable = texture;
                                this.preview_stack.set_visible_child (this.preview_picture1 as Gtk.Widget);
                            }
                            this.settings.set_string ("picture-uri", file.get_uri());
                        } catch (Error e) {
                            error (e.message);
                        }
                    }
                    this.spinner.spinning = false;
                    this.spinner.visible = false;
                });
                chooser.show ();
            });
        }
    }
}
