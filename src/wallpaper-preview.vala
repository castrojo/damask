/* wallpaper-preview.vala
 *
 * Copyright 2023 Link Dupont <link@sub-pop.net>
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
    [GtkTemplate (ui = "/app/drey/Damask/wallpaper-preview.ui")]
    public class WallpaperPreview : Gtk.Box {
        [GtkChild] private unowned Gtk.Stack stack;
        [GtkChild] private unowned Gtk.Picture picture1;
        [GtkChild] private unowned Gtk.Picture picture2;
        [GtkChild] private unowned Gtk.Label title;
        [GtkChild] private unowned Gtk.Label description;
        [GtkChild] private unowned Gtk.Button open_url;

        private WallpaperSource? _source;
        public string source {
            get { return this._source.id; }
            construct set {
                if (this._source != null) {
                    this._source.notify["current-wallpaper"].disconnect (this.refresh_source);
                }
                Application application = GLib.Application.get_default () as Application;
                this._source = application.sources.get (value);
                this._source.notify["current-wallpaper"].connect (this.refresh_source);
                if (application.settings.get_string ("active-source") != value) {
                    this._source.refresh.begin ();
                } else {
                    this.refresh_source ();
                }
            }
        }

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
        }

        private void refresh_source () {
            this.refresh_source_async.begin ();
        }

        private async void refresh_source_async () {
            debug (@"[%p] $(this.get_type().name()).refresh_source_async", this);
            yield this.refresh_picture ();

            if (this._source.current_wallpaper != null) {
                this.open_url.visible = this._source.current_wallpaper.web_url != null;

                this.title.visible = this._source.current_wallpaper.title != null;
                if (this._source.current_wallpaper.title != null) {
                    this.title.set_markup (this._source.current_wallpaper.title);
                }

                this.description.visible = this._source.current_wallpaper.description != null;
                if (this._source.current_wallpaper.description != null) {
                    this.description.set_markup (this._source.current_wallpaper.description);
                }
            } else {
                this.stack.set_visible_child_name ("placeholder");
                this.open_url.visible = false;
            }
        }

        private void set_paintable_swap (Gdk.Paintable texture) {
            int width = int.min (300, texture.get_intrinsic_width ());
            int height = int.min (200, texture.get_intrinsic_height ());
            if (this.stack.get_visible_child_name () == "picture1" ) {
                this.picture2.paintable = texture;
                this.picture2.width_request = width;
                this.picture2.height_request = height;
                this.stack.set_visible_child_name ("picture2");
            } else {
                this.picture1.paintable = texture;
                this.picture1.width_request = width;
                this.picture1.height_request = height;
                this.stack.set_visible_child_name ("picture1");
            }
        }

        private async void refresh_picture () {
            debug (@"[%p] $(this.get_type().name()).refresh_picture", this);
            try {
                if (this._source.current_wallpaper != null) {
                    Uri uri = Uri.parse (this._source.current_wallpaper.thumbnail_url, UriFlags.NONE);
                    Gdk.Texture? texture = null;

                    switch (uri.get_scheme ()) {
                    case "file":
                        string uri_string = uri.to_string ();
                        File file = File.new_for_uri (uri_string);
                        texture = Gdk.Texture.from_file (file);
                        break;
                    default:
                        Soup.Session session = new Soup.Session ();
                        Soup.Message msg = new Soup.Message ("GET", uri.to_string ());
                        Bytes body = yield session.send_and_read_async (msg, 0, null);
                        texture = Gdk.Texture.from_bytes (body);
                        break;
                    }
                    this.set_paintable_swap (texture);
                }
            } catch (Error e) {
                message (e.message);
            }
        }

        ~WallpaperPreview () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
