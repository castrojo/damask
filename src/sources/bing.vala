/* bing.vala
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

namespace Damask.Sources.Bing {
    internal class Response : Object, Json.Serializable {
        internal Gee.ArrayList<Image> images { get; set; }

        internal override bool deserialize_property (string property_name, out Value value, ParamSpec pspec, Json.Node property_node) {
            switch (property_name) {
                case "images":
                    var arr = new Gee.ArrayList<Image> ();
			        property_node.get_array ().foreach_element ((array, i, elem) => {
				        var obj = Json.gobject_deserialize (typeof(Image), elem) as Image;
				        arr.add (obj);
			        });
			        value = arr;
                    return true;
                default:
                    return default_deserialize_property (property_name, out value, pspec, property_node);
            }
        }
   }

    internal class Image : Object, Json.Serializable {
        internal string urlbase { get; set; }
        internal string title { get; set; }
        internal string copyright { get; set; }
        internal string copyrightlink { get; set; }
    }

    public class Bing : Object, WallpaperSource {
        private Settings settings = new Settings(@"$(Constants.APP_ID).sources.bing");

        public string id {
            get { return "bing"; }
        }

        public string title {
            get { return _("Bing Wallpaper"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            string mkt = this.settings.get_string ("market");

            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", @"https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$mkt");

            try {
                Bytes response_body = yield session.send_and_read_async (msg, 0, null);
                debug ((string) response_body.get_data ());
                Response resp = Json.gobject_from_data (typeof(Response), (string) response_body.get_data ()) as Response;
                assert (resp != null);

                Image image = resp.images.first();

                string resolution = this.settings.get_string ("resolution");
                if (resolution == "UHD (3840x2160)") {
                    resolution = "UHD";
                }

                string path = @"https://www.bing.com$(image.urlbase)_$resolution.jpg";
                debug (path);

                this.current_wallpaper = new Damask.Wallpaper () {
                    url = path,
                    thumbnail_url = @"https://www.bing.com/$(image.urlbase)_320x240.jpg",
                    title = image.title,
                    web_url = image.copyrightlink,
                    description = image.copyright,
                };
                return this.current_wallpaper;
            } catch (Error e) {
                this.toast (_("Failed to get wallpaper: %s").printf(e.message));
                message (e.message);
            }
            return null;
        }

        public Adw.PreferencesPage? preferences () {
            return new PreferencesPage () as Adw.PreferencesPage;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/bing.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings(@"$(Constants.APP_ID).sources.bing");

        [GtkChild] private unowned Adw.ComboRow market;
        [GtkChild] private unowned Adw.ComboRow resolution;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            this.market.selected = this.settings.get_enum ("market");
            this.market.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("market", (int) market.selected);
            });

            this.resolution.selected = this.settings.get_enum ("resolution");
            this.resolution.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("resolution", (int) resolution.selected);
            });
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
