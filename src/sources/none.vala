/* none.vala
 *
 * Copyright 2024 Link Dupont <link@sub-pop.net>
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

 namespace Damask.Sources.None {
    public class None : Object, WallpaperSource {
        public string id {
            get { return "none"; }
        }

        public string title {
            get { return _("None"); }
        }

        public Wallpaper? current_wallpaper { get; internal set; }

        public async Wallpaper? refresh () {
            return null;
        }

        public bool can_refresh {
            get { return false; }
        }

        public Adw.PreferencesPage? preferences () {
            return new PreferencesPage () as Adw.PreferencesPage;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/none.ui")]
    public class PreferencesPage : Adw.PreferencesPage {}
 }
