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
    }

    public interface WallpaperSource : Object {
        public abstract void refresh() throws Error;
        public abstract Adw.PreferencesWindow? preferences ();
        public abstract string id { get; }
        public abstract string title { get; }
        public abstract string subtitle { get; }
        public abstract bool can_activate { get; }
        public abstract unowned Wallpaper? current_wallpaper { get; }

        public signal void changed(string uri);
    }
}
