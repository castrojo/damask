/* preferences.vala
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
    [GtkTemplate (ui = "/app/drey/Damask/preferences.ui")]
    public class PreferencesWindow : Adw.PreferencesWindow {
        private static Gee.ArrayList<uint> intervals = new Gee.ArrayList<uint>.wrap ({ 30, 60, 300, 900, 1800, 3600, 21600, 43200, 86400 });
        [GtkChild] private unowned Adw.ComboRow refresh_interval;
        [GtkChild] private unowned Gtk.Switch run_in_background;
        [GtkChild] private unowned Gtk.Switch autostart;

        construct {
            Application.settings.bind("run-in-background", run_in_background, "state", SettingsBindFlags.DEFAULT);
            Application.settings.bind("autostart", autostart, "state", SettingsBindFlags.DEFAULT);

            uint32 current_interval = Application.settings.get_uint ("refresh-interval");
            refresh_interval.selected = intervals.index_of (current_interval);
            refresh_interval.notify["selected"].connect ((pspec) => {
                Application.settings.set_uint ("refresh-interval", intervals.get ((int) refresh_interval.selected));
            });
        }
    }
}
