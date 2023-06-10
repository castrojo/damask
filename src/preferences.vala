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
        [GtkChild] private unowned Adw.ComboRow refresh_interval;
        [GtkChild] private unowned Gtk.Switch run_in_background;
        [GtkChild] private unowned Gtk.Switch autostart;

        construct {
            Application application = GLib.Application.get_default () as Application;
            application.settings.bind("run-in-background", run_in_background, "active", SettingsBindFlags.DEFAULT);
            application.settings.bind("autostart", autostart, "active", SettingsBindFlags.DEFAULT);

            refresh_interval.selected = application.settings.get_enum ("refresh-interval");
            refresh_interval.notify["selected"].connect ((pspec) => {
                application.settings.set_enum ("refresh-interval", (int) refresh_interval.selected);
            });
        }
    }
}
