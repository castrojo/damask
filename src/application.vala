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
        public bool is_refreshing { get; private set; default = false; }
        public Gee.HashMap<string, WallpaperSource> sources = new Gee.HashMap<string, WallpaperSource> ();

        private WallpaperSource? current_source = null;
        private uint source_id = 0;
        private bool skip_window = false;

        public Application () {
            Object (application_id: Constants.APP_ID, flags: ApplicationFlags.FLAGS_NONE);
        }

        construct {
            ActionEntry[] action_entries = {
                { "refresh", this.refresh_current_source },
                { "about", this.on_action_about },
                { "preferences", this.on_action_preferences },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);

            var enable_automatic_refresh_action = this.settings.create_action ("enable-automatic-refresh");
            enable_automatic_refresh_action.notify["state"].connect (this.on_automatic_refresh_action);
            this.add_action (enable_automatic_refresh_action);

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
                var s = new Sources.Slideshow.Slideshow ();
                this.sources.set (s.id, s);
                Type? type = typeof (Sources.Slideshow.PreferencesPage);
            }
            {
                var s = new Sources.Bing.Bing ();
                this.sources.set (s.id, s);
                Type? type = typeof (Sources.Bing.PreferencesPage);
            }
            {
                var s = new Sources.Wallhaven.Wallhaven ();
                this.sources.set (s.id, s);
                Type? type = typeof (Sources.Wallhaven.PreferencesPage);
            }
            {
                var s = new Sources.Apod.Apod ();
                this.sources.set (s.id, s);
                Type? type = typeof (Sources.Apod.PreferencesPage);
            }
            if (Damask.Constants.UNSPLASH_ACCESS_KEY != "") {
                var s = new Sources.Unsplash.Unsplash ();
                this.sources.set (s.id, s);
                Type? type = typeof (Sources.Unsplash.PreferencesPage);
            }
            {
                var s = new Sources.EarthView.EarthView ();
                this.sources.set (s.id, s);
                Type? type = typeof (Sources.EarthView.PreferencesPage);
            }
        }

        public override void startup () {
            this.resource_base_path = "/app/drey/Damask";
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

            /* connect to the active-source settings key */
            this.settings.changed["active-source"].connect (this.active_source_changed);

            if (this.settings.get_boolean ("run-in-background")) {
                this.hold ();
            }

            /* get the active source and set it up */
            this.active_source_changed ();
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

        private void active_source_changed () {
            debug ("active_source_changed");
            if (this.current_source != null) {
                debug (@"disabling $(this.current_source.id)");
                this.current_source.request_refresh.disconnect (this.refresh_current_source);
                this.current_source.toast.disconnect (this.current_source_toast);
                this.detach_timer ();
            }
            this.current_source = this.sources.get (this.settings.get_string ("active-source"));
            if (this.current_source != null) {
                this.is_refreshing = false;
                debug (@"enabling $(this.current_source.id)");
                this.attach_timer ();
                this.current_source.request_refresh.connect (this.refresh_current_source);
                this.current_source.toast.connect (this.current_source_toast);
                this.refresh_current_source_async.begin ();
            }
        }

        private void refresh_current_source () {
            MainContext context = MainContext.default ();
            Source source = context.find_source_by_id (this.source_id);
            int64 seconds = int64.parse (this.settings.get_string("refresh-interval"));
            source.set_ready_time (GLib.get_monotonic_time () + (seconds * 1000000));
            this.refresh_current_source_async.begin ();
        }

        private async void refresh_current_source_async () {
            if (this.current_source == null || this.is_refreshing) return;
            var source = this.current_source;
            this.is_refreshing = true;
            debug (@"refreshing $(source.id)");

            var wallpaper = yield source.refresh ();
            if (this.current_source != source) {
                return; // the user changed the source
            }
            if (wallpaper == null) {
                debug (@"finished refreshing $(source.id); no wallpaper retrieved");
                this.current_wallpaper = null;
                this.is_refreshing = false;
                return;
            }

            Xdp.Portal portal = new Xdp.Portal ();
            try {
                var success = yield portal.set_wallpaper (null, wallpaper.url, Xdp.WallpaperFlags.BACKGROUND, null);
                debug (@"finished setting wallpaper");
                if (success) {
                    this.current_wallpaper = wallpaper;
                } else {
                    this.current_source_toast (_("Unable to set wallpaper"));
                }
            } catch (Error e) {
                this.current_source_toast (_("Unable to set wallpaper: %s").printf(e.message));
            } finally {
                this.is_refreshing = false;
            }
        }

        private void current_source_toast (string message) {
            var window = (this.active_window as Window);
            if (window != null) {
                var action = window.lookup_action ("show-toast");
                action.activate (new Variant.string (message));
            }
        }

        private void attach_timer () {
            debug (@"[%p] $(this.get_type().name()).attach_timer", this);
            if (!this.settings.get_boolean ("enable-automatic-refresh")) {
                info (@"enable-automatic-refresh disabled - not installing refresh timer");
                return;
            }
            int seconds = int.parse (this.settings.get_string("refresh-interval"));
            TimeoutSource timer = new TimeoutSource.seconds (seconds);
            timer.set_callback (() => {
                debug (@"[%p] $(this.get_type().name()) timer callback", this);
                this.refresh_current_source_async.begin ();
                return true;
            });
            timer.attach ();
            this.source_id = timer.get_id ();
        }

        private void detach_timer () {
            debug (@"[%p] $(this.get_type().name()).detach_timer", this);
            if (this.source_id > 0) {
                Source.remove (this.source_id);
                this.source_id = 0;
            }
        }

        private void install_autostart () {
            Xdp.Portal portal = new Xdp.Portal ();
            GenericArray<weak string> cmd = new GenericArray<weak string> ();
            cmd.add ("damask");
            cmd.add ("--background");
            portal.request_background.begin (null, null, cmd, Xdp.BackgroundFlags.AUTOSTART, null, (src, res) => {
                try {
                    if (!portal.request_background.end (res)) {
                        this.current_source_toast (_("Unable to activate autostart"));
                    }
                } catch (Error e) {
                    this.current_source_toast (_("Unable to activate autostart: %s").printf(e.message));
                }
            });
        }

        private void remove_autostart () {
            Xdp.Portal portal = new Xdp.Portal ();
            GenericArray<weak string> cmd = new GenericArray<weak string> ();
            cmd.add ("damask");
            cmd.add ("--background");
            portal.request_background.begin (null, null, cmd, Xdp.BackgroundFlags.NONE, null, (src, res) => {
                try {
                    if (!portal.request_background.end (res)) {
                        this.current_source_toast (_("Unable to deactivate autostart"));
                    }
                } catch (Error e) {
                    this.current_source_toast (_("Unable to deactivate autostart: %s").printf(e.message));
                }
            });
        }

        private void on_automatic_refresh_action () {
            debug ("@[%p] $(this.get_type().name()).on_automatic_refresh_action", this);
            bool autorefresh = this.settings.get_boolean ("enable-automatic-refresh");
            debug (@"enable-automatic-refresh: $(autorefresh)");
            if (autorefresh) {
                this.attach_timer ();
            } else {
                this.detach_timer ();
            }
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
    }
}

