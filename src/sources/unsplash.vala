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
        internal User user { get; set; }
    }

    internal class Urls : Object, Json.Serializable {
        internal string raw { get; set; }
        internal string full { get; set; }
        internal string thumb { get; set; }
    }

    internal class Links : Object, Json.Serializable {
        internal string html { get; set; }
    }

    internal class User : Object, Json.Serializable {
        internal string name { get; set; }
        internal string portfolio_url { get; set; }
    }

    public class Unsplash : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.unsplash");

        construct {
        }

        public string id {
            get { return "unsplash"; }
        }

        public string title {
            get { return _("Unsplash"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            StringBuilder query_parameters = new StringBuilder ();

            string query = this.settings.get_string ("query");
            query_parameters.append (@"query=$query&");

            query_parameters.append ("orientation=landscape&");

            string content_filter = this.settings.get_string ("content-filter");
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
            msg.get_request_headers().append ("Authorization", @"Client-ID $(Damask.Constants.UNSPLASH_ACCESS_KEY)");
            msg.get_request_headers().append ("Accept-Version", "v1");
            debug (msg.uri.to_string());

            try {
                Bytes response_body = yield session.send_and_read_async (msg, 0, null);
                debug ((string) response_body.get_data ());
                Image img = Json.gobject_from_data (typeof(Image), (string) response_body.get_data ()) as Image;
                assert (img != null);

                this.current_wallpaper = new Damask.Wallpaper () {
                    url = img.urls.full,
                    thumbnail_url = img.urls.thumb,
                    description = img.description.strip (),
                    web_url = img.links.html,
                    attribution = _("Photo by <a href=\"%s?utm_source=damask&amp;utm_medium=referral\">%s</a> on <a href=\"https://unsplash.com/?utm_source=damask&amp;utm_medium=referral\">Unsplash</a>.").printf(img.user.portfolio_url, img.user.name),
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

    [GtkTemplate (ui = "/app/drey/Damask/sources/unsplash.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.unsplash");

        [GtkChild] private unowned Adw.EntryRow query;
        [GtkChild] private unowned Adw.EntryRow collections;
        [GtkChild] private unowned Adw.EntryRow topics;
        [GtkChild] private unowned Adw.ComboRow content_filter;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            this.settings.bind ("query", query, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind ("collections", collections, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind ("topics", topics, "text", SettingsBindFlags.DEFAULT);

            this.content_filter.selected = this.settings.get_enum ("content-filter");
            this.content_filter.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("content-filter", (int) this.content_filter.selected);
            });
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
