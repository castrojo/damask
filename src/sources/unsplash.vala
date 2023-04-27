/* unsplash.vala
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

namespace Damask.Sources.Unsplash {
    internal class Image : Object, Json.Serializable {
        internal string id { get; set; }
        internal int width { get; set; }
        internal int height { get; set; }
        internal string description { get; set; }
        internal Links links { get; set; }
        internal Urls urls { get; set; }
    }

    internal class Urls : Object, Json.Serializable {
        internal string raw { get; set; }
        internal string full { get; set; }
        internal string thumb { get; set; }
    }

    internal class Links : Object, Json.Serializable {
        internal string html { get; set; }
    }

    public class Unsplash : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.unsplash");

        construct {
            this.settings.changed["api-key"].connect (() => {
                this.notify_property ("can-activate");
            });
        }

        public string id {
            get { return "unsplash"; }
        }

        public string title {
            get { return "Unsplash"; }
        }

        public string subtitle {
            get { return _("Get wallpapers from unsplash.com"); }
        }

        public bool can_activate {
            get { return this.settings.get_string ("api-key") != ""; }
        }

        private Damask.Wallpaper? _current_wallpaper;
        public unowned Damask.Wallpaper? current_wallpaper {
            get { return _current_wallpaper; }
        }

        public void refresh () throws Error {
            StringBuilder query_parameters = new StringBuilder ();

            string query = this.settings.get_string ("query");
            query_parameters.append (@"query=$query&");

            query_parameters.append ("orientation=landscape&");

            string content_filter = this.settings.get_string ("content_filter");
            query_parameters.append (@"content_filter=$content_filter&");

            if (this.settings.get_string ("collections") != "") {
                string collections = this.settings.get_string ("collections");
                query_parameters.append (@"collections=$collections&");
            }

            if (this.settings.get_string ("topics") != "") {
                string topics = this.settings.get_string ("topics");
                query_parameters.append (@"topics=$topics&");
            }

            string url = @"https://api.unsplash.com/photos/random?$(query_parameters.str)";
            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", url);
            string api_key = this.settings.get_string ("api-key");
            msg.get_request_headers().append ("Authorization", @"Client-ID $api_key");
            msg.get_request_headers().append ("Accept-Version", "v1");
            debug (msg.uri.to_string());

            session.send_and_read_async.begin (msg, 0, null, (source, result) => {
                Application application = GLib.Application.get_default () as Application;
                try {
                    Bytes response_body = session.send_and_read_async.end (result);
                    debug ((string) response_body.get_data ());
                    Image img = Json.gobject_from_data (typeof(Image), (string) response_body.get_data ()) as Image;
                    assert (img != null);

                    this._current_wallpaper = new Damask.Wallpaper () {
                        url = img.urls.full,
                        thumbnail_url = img.urls.thumb,
                        description = img.description,
                        web_url = img.links.html
                    };
                    if (this._current_wallpaper.description == null)

                    this.changed (img.urls.full);
                } catch (Error e) {
                    application.window.show_toast (new Adw.Toast (_(@"Unable to set wallpaper: $(e.message)")));
                }
            });
        }

        public Adw.PreferencesWindow? preferences () {
            return new PreferencesWindow () as Adw.PreferencesWindow;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/unsplash.ui")]
    public class PreferencesWindow : Adw.PreferencesWindow {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.unsplash");

        [GtkChild] private unowned Adw.EntryRow api_key;
        [GtkChild] private unowned Adw.EntryRow query;
        [GtkChild] private unowned Adw.EntryRow collections;
        [GtkChild] private unowned Adw.EntryRow topics;
        [GtkChild] private unowned Adw.ComboRow content_filter;

        construct {
            this.settings.bind ("api-key", api_key, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind ("query", query, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind ("collections", collections, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind ("topics", topics, "text", SettingsBindFlags.DEFAULT);

            this.content_filter.selected = this.settings.get_enum ("content-filter");
            this.content_filter.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("content-filter", (int) this.content_filter.selected);
            });
        }
    }
}
