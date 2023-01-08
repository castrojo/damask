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
        public static Settings settings = new Settings (Constants.APP_ID);

        public ListStore sources = new ListStore (typeof(WallpaperSource));

        private Gee.HashMap<string, WallpaperSource> sources_map = new Gee.HashMap<string, WallpaperSource> ();
        private WallpaperSource? active_source;
        private uint source_id;
        private bool skip_window = false;

        public Application () {
            Object (application_id: Constants.APP_ID, flags: ApplicationFlags.FLAGS_NONE);
        }

        construct {
            ActionEntry[] action_entries = {
                { "refresh", this.on_refresh_action },
                { "info", this.on_info_action },
                { "about", this.on_about_action },
                { "preferences", this.on_preferences_action },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);
            this.set_accels_for_action ("app.quit", {"<primary>q"});

            OptionEntry[] option_entries = {
                {
                    "background",
                    'b',
                    OptionFlags.NONE,
                    OptionArg.NONE,
                    null,
                    "Background the application immediately, bypassing the main window",
                    null
                }
            };
            this.add_main_option_entries (option_entries);

            sources.append(new Sources.Manual.Manual());
            sources.append(new Sources.Bing.Bing());
            sources.append(new Sources.Wallhaven.Wallhaven());

            for (int i = 0; i < sources.get_n_items (); i++) {
                var source = sources.get_item (i) as WallpaperSource;
                sources_map.set(source.title, source);
            }

            active_source = sources_map.get(Application.settings.get_string ("active-source"));
        }

        public override int handle_local_options (VariantDict options) {
            this.skip_window = options.contains ("background");
            return -1;
        }

        public override void startup () {
            base.startup ();

            this.install_timer ();
            active_source.changed.connect (this.on_active_source_changed);

            Application.settings.changed["active-source"].connect((key) => {
                debug(@"deactivating $(active_source.title)");
                Source.remove (this.source_id);
                this.source_id = 0;
                active_source.changed.disconnect (this.on_active_source_changed);

                active_source = sources_map.get(Application.settings.get_string (key));
                this.install_timer ();
                active_source.changed.connect (this.on_active_source_changed);
                debug(@"activating $(active_source.title)");
            });

            Application.settings.changed["refresh-interval"].connect ((key) => {
                Source.remove (this.source_id);
                this.install_timer ();
            });

            Application.settings.changed["run-in-background"].connect ((key) => {
                if (Application.settings.get_boolean (key)) {
                    this.hold ();
                } else {
                    this.release ();
                }
            });

            if (Application.settings.get_boolean ("run-in-background")) {
                this.hold ();
            }

            Application.settings.changed["autostart"].connect ((key) => {
                if (Application.settings.get_boolean (key)) {
                    Xdp.Portal portal = new Xdp.Portal ();
                    GenericArray<weak string> commandline = new GenericArray<weak string> ();
                    commandline.add ("damask");
                    commandline.add ("--background");
                    portal.request_background.begin (null,
                                                     "Running automatically",
                                                     commandline,
                                                     Xdp.BackgroundFlags.AUTOSTART,
                                                     null,
                                                     (src, res) => {
                        try {
                            if (!portal.request_background.end (res)) {
                                error ("background request failed");
                            }
                        } catch (Error e) {
                            error (e.message);
                        }
                    });
                } else {
                    Xdp.Portal portal = new Xdp.Portal ();
                    GenericArray<weak string> commandline = new GenericArray<weak string> ();
                    portal.request_background.begin (null, null, commandline, Xdp.BackgroundFlags.NONE, null, (src, res) => {
                        try {
                            if (!portal.request_background.end (res)) {
                                error ("background request failed");
                            }
                        } catch (Error e) {
                            error (e.message);
                        }
                    });
                }
            });
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

        private void on_about_action () {
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

        private void on_preferences_action () {
            var prefs = new Damask.PreferencesWindow ();
            prefs.set_transient_for (this.active_window);
            prefs.present ();
        }

        private void on_refresh_action () {
            this.active_source.refresh();
        }

        private void on_info_action () {
            var info = new Damask.InfoWindow (this, this.active_source.current_wallpaper);
            info.set_transient_for (this.active_window);
            info.present ();
        }

        private void on_active_source_changed (string uri) {
            Xdp.Portal portal = new Xdp.Portal ();
            portal.set_wallpaper.begin (null, uri, Xdp.WallpaperFlags.BACKGROUND, null, (src, res) => {
                try {
                    if (portal.set_wallpaper.end (res)) {
                        info(@"wallpaper set to $uri");
                    } else {
                        error("failed to set wallpaper");
                    }
                } catch (Error e) {
                    error("cannot set wallpaper: %s", e.message);
                }
            });
        }

        private void install_timer () {
            uint seconds = Application.settings.get_uint ("refresh-interval");
            var timer = new TimeoutSource.seconds ((int) seconds);
            timer.set_callback(() => {
                debug (@"timer $(timer.get_id ()) fired");
                active_source.refresh ();
                return true;
            });
            timer.attach ();
            this.source_id = timer.get_id ();
        }
    }
}
