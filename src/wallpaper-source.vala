/* wallpaper-source.vala
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
    public class Wallpaper : Object {
        public string web_url { get; set; }
        public string url { get; set; }
        public string? thumbnail_url { get; set; }
        public string? title { get; set; }
        public string? description { get; set; }
        public string? resolution { get; set; }
        public string? attribution { get; set; }
    }

    public interface WallpaperSource : Object {
        /**
         * refresh:
         *
         * Fetch a new wallpaper from the backend source.
         */
        public abstract async Wallpaper? refresh ();

        /**
         * id:
         *
         * Unique identifier for the source.
         */
        public abstract string id { get; }

        /**
         * title:
         *
         * Display name for the source.
         */
        public abstract string title { get; }

        /**
         * current_wallpaper:
         *
         * The current wallpaper.
         */
        public abstract Wallpaper? current_wallpaper { get; internal set; }

        /**
         * preferences:
         *
         * Return a preferences page for the source.
         */
        public abstract Adw.PreferencesPage? preferences ();

        /**
         * request_refresh:
         *
         * Emitted when the wallpaper source needs to be refreshed. For example,
         * after preferences have changed.
         */
        public signal void request_refresh ();

        /**
         * toast:
         *
         * Emitted when a source needs to display a message via a Toast.
         */
        public signal void toast (string message);

        public static bool equal (Object a, Object b) {
            var source_a = a as WallpaperSource;
            var source_b = b as WallpaperSource;
            return source_a.id == source_b.id;
        }
    }
}
