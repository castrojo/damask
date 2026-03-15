/* spotlight.vala
 *
 * Copyright 2026 Stanislav Stepanchenko 
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

namespace Damask.Sources.Spotlight {
    private const string API_URL = "https://fd.api.iris.microsoft.com/v4/api/selection";
    private const string PLACEMENT = "88000820";

    public class Spotlight : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.spotlight");

        construct {
            this.settings.changed.connect ((key) => {
                this.request_refresh ();
            });
        }

        public string id {
            get { return "spotlight"; }
        }

        public string title {
            get { return _("Windows Spotlight"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public bool can_refresh {
            get { return true; }
        }

        public async Wallpaper? refresh () {
            string locale = this.settings.get_string ("locale");
            string[] parts = locale.split("-");
            string country = parts.length > 1 ? parts[1] : locale;

            string url = @"$API_URL?placement=$PLACEMENT&bcnt=1&country=$country&locale=$locale&fmt=json";

            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", url);

            try {
                Bytes response_body = yield session.send_and_read_async (msg, 0, null);
                string body = (string) response_body.get_data ();
                debug (body);

                // Parse outer response: batchrsp.items[0].item is a JSON string
                Json.Node root = Json.from_string (body);
                Json.Object batchrsp = root.get_object ().get_object_member ("batchrsp");
                Json.Array items = batchrsp.get_array_member ("items");
                string item_json = items.get_object_element (0).get_string_member ("item");

                // Parse inner JSON string
                Json.Node item_node = Json.from_string (item_json);
                Json.Object ad = item_node.get_object ().get_object_member ("ad");

                string image_url = ad.get_object_member ("landscapeImage").get_string_member ("asset");
                string? image_title = ad.has_member ("title") ? ad.get_string_member ("title") : null;
                string? description = null;

                // JSON object contains iconHoverText and description fields. 
                // The former is three short strings: the short description of an image, the copyright and tooltip
                // "right-click to know more" for a native app.
                // The latter is a large flavour text, too big to be chunked into the app preview, which is limited
                // currently to three rows.
                // So the safest way (at least for now) is to extract the first row from short description.
                if (ad.has_member ("iconHoverText")) {
                    string[] lines = ad.get_string_member ("iconHoverText").split ("\n");
                    description = lines[0].strip(); // In case it was \r\n
                    if (description == "") {
                        description = null;
                    }
                }
                string? copyright = ad.has_member ("copyright") ? ad.get_string_member ("copyright") : null;
                string? cta_uri = ad.has_member ("ctaUri") ? ad.get_string_member ("ctaUri") : null;
                if (cta_uri != null && cta_uri.has_prefix ("microsoft-edge:")) {
                    cta_uri = cta_uri.substring ("microsoft-edge:".length);
                }

                this.current_wallpaper = new Damask.Wallpaper () {
                    url = image_url,
                    thumbnail_url = image_url,
                    title = image_title,
                    web_url = cta_uri ?? "",
                    description = description,
                    attribution = copyright,
                };
                return this.current_wallpaper;
            } catch (Error e) {
                this.toast (_("Failed to get wallpaper: %s").printf (e.message));
                message (e.message);
            }
            return null;
        }

        public Adw.PreferencesPage? preferences () {
            return new PreferencesPage () as Adw.PreferencesPage;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/spotlight.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.spotlight");

        [GtkChild] private unowned Adw.ComboRow locale;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            this.locale.selected = this.settings.get_enum ("locale");
            this.locale.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("locale", (int) locale.selected);
            });
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
