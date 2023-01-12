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
        private static Gee.ArrayList<string> markets = new Gee.ArrayList<string>.wrap ({ "en-US", "zh-CN", "ja-JP", "en-AU", "en-GB", "de-DE", "en-NZ", "en-CA", "en-IN", "fr-FR", "fr-CA" });
        private static Gee.ArrayList<string> resolutions = new Gee.ArrayList<string>.wrap ({ "1920x1080", "1366x768", "UHD (3840x2160)" });

        public string id {
            get { return "bing"; }
        }

        public string title {
            get { return "Bing Wallpaper"; }
        }

        public string subtitle {
            get { return "Use Microsoft Bing's wallpaper of the day"; }
        }

        private Damask.Wallpaper? _current_wallpaper;
        public Damask.Wallpaper? current_wallpaper {
            get { return _current_wallpaper; }
        }

        public void refresh () {
            string mkt = this.settings.get_string ("market");

            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", @"https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$mkt");

            session.send_and_read_async.begin (msg, 0, null, (source, result) => {
                try {
                    Bytes response_body = session.send_and_read_async.end (result);
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

                    this._current_wallpaper = new Damask.Wallpaper ();
                    this._current_wallpaper.url = path;
                    this._current_wallpaper.thumbnail_url = @"https://www.bing.com/$(image.urlbase)_320x240.jpg";
                    this._current_wallpaper.title = image.title;
                    this._current_wallpaper.web_url = image.copyrightlink;
                    this._current_wallpaper.description = image.copyright;

                    this.changed(path);
                } catch (Error e) {
                    error (e.message);
                }
            });
        }

        public Adw.PreferencesPage? prefs () {
            Gtk.Builder builder = new Gtk.Builder.from_resource (@"$(Constants.RESOURCE_PATH_PREFIX)/sources/bing.ui");
            Adw.PreferencesPage prefs = builder.get_object("prefs") as Adw.PreferencesPage;

            Adw.ComboRow market = builder.get_object("market") as Adw.ComboRow;
            market.selected = Bing.markets.index_of (this.settings.get_string ("market"));
            market.notify["selected"].connect ((pspec) => {
                this.settings.set_string ("market", Bing.markets.get ((int) market.selected));
            });

            Adw.ComboRow resolution = builder.get_object("resolution") as Adw.ComboRow;
            resolution.selected = Bing.resolutions.index_of (this.settings.get_string ("resolution"));
            resolution.notify["selected"].connect ((pspec) => {
                this.settings.set_string ("resolution", Bing.resolutions.get ((int) resolution.selected));
            });

            return prefs;
        }
    }
}
