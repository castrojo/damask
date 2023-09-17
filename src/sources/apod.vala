/* apod.vala
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

namespace Damask.Sources.Apod {
    internal class Response : Object, Json.Serializable {
        internal string copyright { get; set; }
        internal string date { get; set; }
        internal string explanation { get; set; }
        internal string hdurl { get; set; }
        internal string media_type { get; set; }
        internal string service_version { get; set; }
        internal string title { get; set; }
        internal string url { get; set; }
    }

    public class Apod : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.apod");

        construct {
            this.settings.changed["api-key"].connect (() => {
                this.notify_property ("can-activate");
            });
        }

        public string id {
            get { return "apod"; }
        }

        public string title {
            get { return _("NASA Astronomy"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            StringBuilder query_parameters = new StringBuilder ();

            query_parameters.append (@"api_key=$(Damask.Constants.NASA_API_KEY)&");

            uint min_width = 0;
            Gdk.Display default_display = Gdk.Display.get_default ();
            ListModel model = default_display.get_monitors();
            for (int i = 0; i < model.get_n_items(); i++) {
                Gdk.Monitor m = model.get_object(i) as Gdk.Monitor;
                Gdk.Rectangle rect = m.get_geometry();
                if (rect.width > min_width) {
                    min_width = rect.width;
                }
            }

            string url = @"https://api.nasa.gov/planetary/apod?$(query_parameters.str)";

            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", url);

            try {
                Bytes response_body = yield session.send_and_read_async (msg, 0, null);
                Response resp = Json.gobject_from_data (typeof(Response), (string) response_body.get_data ()) as Response;
                assert (resp != null);

                string image_url = resp.url;
                if (min_width > 1097) {
                    image_url = resp.hdurl;
                }

                this.current_wallpaper = new Damask.Wallpaper () {
                    url = image_url,
                    thumbnail_url = resp.url,
                    title = resp.title,
                    description = resp.explanation,
                    web_url = "https://apod.nasa.gov/apod/",
                };
                return this.current_wallpaper;
            } catch (Error e) {
                this.toast (_("Failed to get image: %s").printf(e.message));
                message (e.message);
            }
            return null;
        }

        public Adw.PreferencesPage? preferences () {
            return new PreferencesPage () as Adw.PreferencesPage;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/apod.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
