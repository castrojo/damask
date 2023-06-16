/* earthview.vala
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

namespace Damask.Sources.EarthView {
    internal class Slug : Object, Json.Serializable {
        internal string id { get; set; }
        internal string name { get; set; }
        internal string slug { get; set; }
        internal string title { get; set; }
        internal string attribution { get; set; }
        internal string photoUrl { get; set; }
        internal string thumbUrl { get; set; }
        internal string shareUrl { get; set; }
        internal string nextSlug { get; set; }
        internal string prevSlug { get; set; }
    }

    public class EarthView : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.earthview");
        private int current_index = 0;

        public string id {
            get { return "earthview"; }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", "https://earthview.withgoogle.com/_api/photos.json");

            try {
                Bytes response_body = yield session.send_and_read_async (msg, 0, null);
                Json.Node node = Json.from_string ((string) response_body.get_data ());
                Json.Array slugs = node.get_array ();
                assert (slugs != null);

                var index = this.current_index;
                switch (this.settings.get_enum ("sort-by")) {
                    case 0:
                        index = (int) Random.int_range (0, (int32) slugs.get_length ());
                        break;
                    case 1:
                        index = this.current_index;
                        this.current_index++;
                        break;
                    default:
                        index = (int) Random.int_range (0, (int32) slugs.get_length ());
                        break;
                }

                Json.Object lede = slugs.get_object_element (index);
                string slug_lede = lede.get_string_member ("slug");

                Soup.Message slug_msg = new Soup.Message ("GET", @"https://earthview.withgoogle.com/_api/$(slug_lede).json");
                Bytes slug_response_body = yield session.send_and_read_async (slug_msg, 0, null);
                Slug slug = Json.gobject_from_data (typeof(Slug), (string) slug_response_body.get_data ()) as Slug;
                assert (slug != null);

                this.current_wallpaper = new Damask.Wallpaper () {
                    url = slug.photoUrl,
                    thumbnail_url = slug.thumbUrl,
                    web_url = slug.shareUrl,
                    title = slug.title,
                    description = slug.attribution,
                };
                return this.current_wallpaper;
            } catch (Error e) {
                this.toast (_("Failed to get image: %s").printf(e.message));
                message (e.message);
            }
            return null;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/earthview.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.earthview");

        [GtkChild] private unowned Adw.ComboRow sort_by;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            this.sort_by.selected = this.settings.get_enum ("sort-by");
            this.sort_by.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("sort-by", (int) sort_by.selected);
            });
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
