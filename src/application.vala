/* application.vala
 *
 * Copyright 2022 Link Dupont
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
    public class Application : Adw.Application {
        public Settings settings = new Settings (Constants.APP_ID);
        public Wallpaper? current_wallpaper { get; private set; }
        public Gee.ArrayList<WallpaperSource> source_list = new Gee.ArrayList<WallpaperSource> ();

        private HashTable<string, WallpaperSource> sources = new HashTable<string, WallpaperSource> (str_hash, str_equal);
        private unowned WallpaperSource? current_source = null;
        private uint source_id = 0;
        private bool skip_window = false;

        public Application () {
            Object (application_id: Constants.APP_ID, flags: ApplicationFlags.FLAGS_NONE);
        }

        construct {
            ActionEntry[] action_entries = {
                { "refresh", this.on_action_refresh },
                { "about", this.on_action_about },
                { "preferences", this.on_action_preferences },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);
            this.set_accels_for_action ("app.quit", {"<primary>q"});
            this.set_accels_for_action ("app.refresh", {"<primary>r"});

            OptionEntry[] option_entries = {
                {
                    "background",
                    'b',
                    OptionFlags.NONE,
                    OptionArg.NONE,
                    null,
                    "Run application in the background",
                    null
                }
            };
            this.add_main_option_entries (option_entries);

            {
                var s = new Sources.Manual.Manual ();
                this.sources.insert (s.id, s);
                this.source_list.add (s);
            }
            {
                var s = new Sources.Bing.Bing ();
                this.sources.insert (s.id, s);
                this.source_list.add (s);
            }
            {
                var s = new Sources.Wallhaven.Wallhaven ();
                this.sources.insert (s.id, s);
                this.source_list.add (s);
            }
        }

        public override void startup () {
            base.startup ();

            /* reattach the timer when refresh-interval changes */
            this.settings.changed["refresh-interval"].connect ((key) => {
                debug (@"settings changed: $key");
                this.detach_timer ();
                this.attach_timer ();
            });

            /* hold/release application when run-in-background changes */
            this.settings.changed["run-in-background"].connect ((key) => {
                debug (@"settings changed: $key");
                if (this.settings.get_boolean ("run-in-background")) {
                    this.hold ();
                } else {
                    this.release ();
                }
            });

            /* install/remove autostart desktop file when autostart changes */
            this.settings.changed["autostart"].connect ((key) => {
                debug (@"settings changed: $key");
                if (this.settings.get_boolean ("autostart")) {
                    this.install_autostart ();
                } else {
                    this.remove_autostart ();
                }
            });

            this.settings.changed["active-source"].connect ((key) => {
                debug (@"settings changed: $key");
                if (this.current_source.id == this.settings.get_string ("active-source")) {
                    debug (@"disabling $(this.current_source.id)");
                    this.current_source.changed.disconnect (this.current_source_changed);
                    this.detach_timer ();
                } else {
                    this.current_source = this.sources.get (this.settings.get_string ("active-source"));
                    debug (@"enabling $(this.current_source.id)");
                    this.attach_timer ();
                    this.current_source.changed.connect (this.current_source_changed);
                    this.current_source.refresh ();
                }
            });

            if (this.settings.get_boolean ("run-in-background")) {
                this.hold ();
            }
            this.current_source = this.sources.get (this.settings.get_string ("active-source"));
            this.current_source.changed.connect (this.current_source_changed);
            this.current_source.refresh ();
            this.attach_timer ();
        }

        public override void activate () {
            base.activate ();

            if (!this.skip_window) {
                var win = this.active_window;
                if (win == null) {
                    win = new Damask.Window (this);
                }
                win.present ();
            }
            this.skip_window = false;
        }

        public override int handle_local_options (VariantDict options) {
            this.skip_window = options.contains ("background");
            return -1;
        }

        private void current_source_changed (string uri) {
            Xdp.Portal portal = new Xdp.Portal ();
            portal.set_wallpaper.begin (null, uri, Xdp.WallpaperFlags.BACKGROUND, null, (src, res) => {
                try {
                    if (portal.set_wallpaper.end (res)) {
                        this.current_wallpaper = this.current_source.current_wallpaper;
                    } else {
                        error ("set_wallpaper failed");
                    }
                } catch (Error e) {
                    error (e.message);
                }
            });
        }

        private void attach_timer () {
            uint seconds = this.settings.get_uint ("refresh-interval");
            TimeoutSource timer = new TimeoutSource.seconds ((int) seconds);
            timer.set_callback (() => {
                this.current_source.refresh ();
                return true;
            });
            timer.attach ();
            this.source_id = timer.get_id ();
        }

        private void detach_timer () {
            Source.remove (this.source_id);
            this.source_id = 0;
        }

        private void install_autostart () {
            Xdp.Portal portal = new Xdp.Portal ();
            GenericArray<weak string> cmd = new GenericArray<weak string> ();
            cmd.add ("damask");
            cmd.add ("--background");
            portal.request_background.begin (null, null, cmd, Xdp.BackgroundFlags.AUTOSTART, null, (src, res) => {
                try {
                    if (!portal.request_background.end (res)) {
                        error ("request_background failed");
                    }
                } catch (Error e) {
                    error (e.message);
                }
            });
        }

        private void remove_autostart () {
            Xdp.Portal portal = new Xdp.Portal ();
            GenericArray<weak string> cmd = new GenericArray<weak string> ();
            portal.request_background.begin (null, null, cmd, Xdp.BackgroundFlags.NONE, null, (src, res) => {
                try {
                    if (!portal.request_background.end (res)) {
                        error ("request_background failed");
                    }
                } catch (Error e) {
                    error (e.message);
                }
            });
        }

        private void on_action_about () {
            string[] developers = { "Link Dupont" };
            var about = new Adw.AboutWindow () {
                transient_for = this.active_window,
                application_name = "Damask",
                application_icon = Constants.APP_ID,
                developer_name = "Link Dupont",
                version = Constants.VERSION,
                developers = developers,
                copyright = "© 2022 Link Dupont",
            };

            about.present ();
        }

        private void on_action_preferences () {
            var prefs = new Damask.PreferencesWindow ();
            prefs.set_transient_for (this.active_window);
            prefs.present ();
        }

        private void on_action_refresh () {
            this.current_source.refresh();
        }
    }
}

