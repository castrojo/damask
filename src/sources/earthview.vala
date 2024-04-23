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
    public class EarthView : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.earthview");
        private int current_index = 0;

        public string id {
            get { return "earthview"; }
        }

        public string title {
            get { return _("Google Earth View"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", "https://github.com/alexpersian/earthview/raw/master/earthview.json");

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

                this.current_wallpaper = new Damask.Wallpaper () {
                    url = lede.get_string_member("image"),
                    thumbnail_url = lede.get_string_member("image"),
                    web_url = lede.get_string_member("map"),
                    description = lede.get_string_member("attribution"),
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
