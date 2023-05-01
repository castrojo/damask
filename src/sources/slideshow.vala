/* slideshow.vala
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

namespace Damask.Sources.Slideshow {
    public class Slideshow : Object, WallpaperSource {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.slideshow");
        private int current_index;
        private Gee.ArrayList<FileInfo> files = new Gee.ArrayList<FileInfo> ();
        private FileMonitor? monitor = null;

        construct {
            this.settings.changed["folder-uri"].connect (() => {
                this.rebuild_file_list ();
            });
            this.settings.changed["sort-by"].connect (() => {
                this.rebuild_file_list ();
            });
            this.rebuild_file_list ();
        }

        public string id {
            get { return "slideshow"; }
        }

        private Damask.Wallpaper? _current_wallpaper;
        public unowned Damask.Wallpaper? current_wallpaper {
            get { return _current_wallpaper; }
        }

        public void refresh () {
            string folder_uri = this.settings.get_string ("folder-uri");
            string? path = null;

            if (this.files.size == 0) {
                return;
            }

            if (this.settings.get_enum ("sort-by") == 0) {
                Rand rand = new Rand ();
                int32 i = rand.int_range (0, (int32) this.files.size);
                FileInfo info = this.files.get (i);
                string name = info.get_name ();
                path = @"$(folder_uri)/$name";
            } else {
                if (this.current_index > this.files.size-1) {
                    this.current_index = 0;
                }
                debug (@"$(this.current_index)");
                FileInfo info = this.files.get (this.current_index);
                string name = info.get_name ();
                path = @"$(folder_uri)/$name";
                this.current_index++;
            }

            if (path != "") {
                debug (path);
                this._current_wallpaper = new Damask.Wallpaper () {
                    url = path,
                    thumbnail_url = path,
                    web_url = path
                };
                this.changed (path);
            }
        }

        private void rebuild_file_list () {
            if (this.settings.get_string("folder-uri") == "") {
                return;
            }

            this.current_index = 0;
            this.files.clear ();

            File folder = File.new_for_uri (this.settings.get_string("folder-uri"));

            try {
                FileEnumerator enumerator = folder.enumerate_children ("standard::*,time::*", FileQueryInfoFlags.NONE, null);
                FileInfo info = null;
                while ((info = enumerator.next_file(null)) != null) {
                    if (info.get_file_type() == FileType.REGULAR) {
                        string content_type = info.get_content_type ();
                        if (content_type == "image/jpeg" || content_type == "image/png") {
                            debug (@"found file $(info.get_name())");
                            this.files.add (info);
                        }
                    }
                }
            } catch (Error e) {
                this.toast (_(@"Failed to get folder contents: $(e.message)"));
                message (e.message);
            }

            switch (this.settings.get_enum("sort-by")) {
                case 1: // name
                    this.files.sort ((a, b) => {
                        return GLib.strcmp (a.get_name(), b.get_name());
                    });
                    break;
                case 2: // creation-date
                    this.files.sort ((a, b) => {
                        uint64 a_created = a.get_attribute_uint64 (FileAttribute.TIME_CREATED);
                        uint64 b_created = b.get_attribute_uint64 (FileAttribute.TIME_CREATED);
                        return (int) (a_created > b_created) - (int) (a_created < b_created);
                    });
                    break;
                case 0: // random
                default:
                    break;
            }

            foreach (FileInfo info in this.files) {
                debug (@"$(info.get_name())");
            }

            if (this.monitor != null)
                this.monitor.cancel ();
            try {
                this.monitor = folder.monitor_directory (FileMonitorFlags.WATCH_MOVES, null);
                this.monitor.changed.connect ((src, dest, event) => {
                    debug (@"$event");
                    this.rebuild_file_list ();
                });
            } catch (Error e) {
                this.toast (_(@"Unable to watch folder for changes: $(e.message)"));
                message (e.message);
            }
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/slideshow.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings (@"$(Constants.APP_ID).sources.slideshow");

        [GtkChild] private unowned Gtk.Button choose_button;
        [GtkChild] private unowned Adw.ActionRow choose_folder_row;
        [GtkChild] private unowned Adw.ComboRow sort_by;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            choose_button.clicked.connect (() => {
                Gtk.FileChooserNative chooser = new Gtk.FileChooserNative (_("Select Folder"),
                                                                           null,
                                                                           Gtk.FileChooserAction.SELECT_FOLDER,
                                                                           _("_Select"),
                                                                           _("_Cancel"));
                chooser.response.connect ((response) => {
                    if (response == Gtk.ResponseType.ACCEPT) {
                        File file = chooser.get_file ();
                        this.settings.set_string ("folder-uri", file.get_uri());
                        this.choose_folder_row.subtitle = file.get_path ();
                    }
                });
                chooser.show ();
            });

            File file = File.new_for_uri (this.settings.get_string ("folder-uri"));
            this.choose_folder_row.subtitle = file.get_path ();
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
