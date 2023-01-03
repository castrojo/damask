/* info-window.vala
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

namespace Damask {
    [GtkTemplate (ui = "/app/drey/Damask/info-window.ui")]
    public class InfoWindow : Adw.ApplicationWindow {
        [GtkChild] private unowned Gtk.Picture preview_picture;
        [GtkChild] private unowned Gtk.Label resolution_label;
        [GtkChild] private unowned Gtk.Label description_label;

        public Wallpaper wallpaper { get; construct set; }

        public InfoWindow (Gtk.Application app, Wallpaper wallpaper) {
            Object(application: app, wallpaper: wallpaper);
        }

        construct {
            ActionEntry[] action_entries = {
                { "open-url", this.on_open_url_action },
            };
            this.add_action_entries (action_entries, this);

            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", wallpaper.thumbnail_url);
                session.send_and_read_async.begin (msg, 0, null, (source, result) => {
                try {
                    Bytes response_body = session.send_and_read_async.end(result);
                    Gdk.Texture texture = Gdk.Texture.from_bytes (response_body);
                    preview_picture.paintable = texture;
                } catch (Error e) {
                    error (e.message);
                }
            });

            if (this.wallpaper.title != null) {
                this.title = this.wallpaper.title;
            }

            this.resolution_label.visible = this.wallpaper.resolution != null;
            if (this.wallpaper.resolution != null) {
                this.resolution_label.set_text (this.wallpaper.resolution);
            }

            if (this.wallpaper.description != null) {
                this.description_label.set_text (this.wallpaper.description);
            }
        }

        void on_open_url_action () {
            Gtk.show_uri (null, this.wallpaper.web_url, Gdk.CURRENT_TIME);
        }
    }
}
