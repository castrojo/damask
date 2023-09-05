/* wallhaven.vala
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

namespace Damask.Sources.Wallhaven {
    internal class Response : Object, Json.Serializable {
        internal Gee.ArrayList<Wallpaper> data { get; set; }
        internal Metadata meta { get; set; }

        internal override bool deserialize_property (string property_name, out Value value, ParamSpec pspec, Json.Node property_node) {
            switch (property_name) {
                case "data":
                    var arr = new Gee.ArrayList<Wallpaper> ();
			        property_node.get_array ().foreach_element ((array, i, elem) => {
				        var obj = Json.gobject_deserialize (typeof(Wallpaper), elem) as Wallpaper;
				        arr.add (obj);
			        });
			        value = arr;
                    return true;
                default:
                    return default_deserialize_property (property_name, out value, pspec, property_node);
            }
        }
    }

    internal class Wallpaper : Object {
        internal string id { get; set; }
        internal string url { get; set; }
        internal string path { get; set; }
        internal string resolution { get; set; }
        internal Thumbnails thumbs { get; set; }
    }

    internal class Thumbnails : Object {
        internal string large { get; set; }
        internal string original { get; set; }
        internal string small { get; set; }
    }

    internal class Metadata : Object, Json.Serializable {
        internal uint current_page { get; set; }
        internal uint last_page { get; set; }
        internal uint total { get; set; }
        internal string? seed { get; set; }
    }

    internal class CollectionList: Object, Json.Serializable {
        internal Gee.ArrayList<Collection> data { get; set; }

        internal override bool deserialize_property (string property_name, out Value value, ParamSpec pspec, Json.Node property_node) {
            switch (property_name) {
                case "data":
                    var arr = new Gee.ArrayList<Collection> ();
			        property_node.get_array ().foreach_element ((array, i, elem) => {
				        var obj = Json.gobject_deserialize (typeof(Collection), elem) as Collection;
				        arr.add (obj);
			        });
			        value = arr;
                    return true;
                default:
                    return default_deserialize_property (property_name, out value, pspec, property_node);
            }
        }
    }

    internal class Collection : Object, Json.Serializable {
        internal uint id { get; set; }
        internal string label { get; set; }
        internal uint views { get; set; }
        internal uint @public { get; set; }
        internal uint count { get; set; }
    }

    internal struct SyntaxExample {
        public string example;
        public string description;
    }

    public class Wallhaven : Object, WallpaperSource {
        private Settings settings = new Settings(@"$(Constants.APP_ID).sources.wallhaven");

        private string seed = "";
        private uint current_index = 0;
        private uint current_page = 1;
        private uint current_total = 0;

        construct {
            this.settings.changed.connect ((key) => {
                this.current_index = 0;
                this.current_page = 1;
                this.current_total = 0;
                this.seed = "";
                this.request_refresh ();
            });
        }

        public string id {
            get { return "wallhaven"; }
        }

        public string title {
            get { return _("Wallhaven"); }
        }

        public Damask.Wallpaper? current_wallpaper { get; internal set; }

        public async Damask.Wallpaper? refresh () {
            string url = "";

            switch (this.settings.get_string ("search-mode")) {
                case "collections":
                    string username = this.settings.get_string ("username");
                    uint id = this.settings.get_uint ("collection-id");

                    url = @"https://wallhaven.cc/api/v1/collections/$username/$id";
                    break;
                case "query":
                    StringBuilder query_parameters = new StringBuilder ();

                    StringBuilder categories = new StringBuilder();
                    this.settings.get_boolean("category-general") == true ? categories.append("1") : categories.append("0");
                    this.settings.get_boolean("category-anime") == true ? categories.append("1") : categories.append("0");
                    this.settings.get_boolean("category-people") == true ? categories.append("1") : categories.append("0");
                    query_parameters.append(@"categories=$(categories.str)&");

                    StringBuilder purity = new StringBuilder();
                    this.settings.get_boolean("purity-sfw") == true ? purity.append("1") : purity.append("0");
                    this.settings.get_boolean("purity-sketchy") == true ? purity.append("1") : purity.append("0");
                    this.settings.get_boolean("purity-nsfw") == true ? purity.append("1") : purity.append("0");
                    query_parameters.append(@"purity=$(purity.str)&");

                    uint min_width = 0;
                    uint min_height = 0;
                    Gdk.Display default_display = Gdk.Display.get_default ();
                    ListModel model = default_display.get_monitors();
                    for (int i = 0; i < model.get_n_items(); i++) {
                        Gdk.Monitor m = model.get_object(i) as Gdk.Monitor;
                        Gdk.Rectangle rect = m.get_geometry();
                        if (rect.width > min_width) {
                            min_width = rect.width;
                        }
                        if (rect.height > min_height) {
                            min_height = rect.height;
                        }
                    }
                    query_parameters.append(@"atleast=$(min_width)x$(min_height)&");

                    if (min_width > 0 && min_height > 0) {
                        uint ratio = 0;
                        string aspect = "";
                        if (min_width > min_height) {
                            ratio = min_width * 10 / min_height;
                        } else {
                            ratio = min_height * 10 / min_width;
                        }
                        switch (ratio) {
                            case 13:
                              aspect = "4x3";
                              break;
                            case 16:
                              aspect = "16x10";
                              break;
                            case 17:
                              aspect = "16x9";
                              break;
                            case 23:
                              aspect = "21x9";
                              break;
                            case 12:
                              aspect = "5x4";
                              break;
                              /* This catches 1.5625 as well (1600x1024) when maybe it shouldn't. */
                            case 15:
                              aspect = "3x2";
                              break;
                            case 18:
                              aspect = "9x5";
                              break;
                            case 10:
                              aspect = "1x1";
                              break;
                        }
                        query_parameters.append(@"ratios=$aspect&");
                    }

                    string sorting = this.settings.get_string ("sort-by");
                    query_parameters.append(@"sorting=$sorting&");

                    string order = "";
                    switch (this.settings.get_int("sort-order")) {
                        case 0:
                            order = "asc";
                            break;
                        case 1:
                            order = "desc";
                            break;
                        default:
                            order = "desc";
                            break;
                    }
                    query_parameters.append(@"order=$order&");

                    if (sorting == "toplist") {
                        string top_list_range = this.settings.get_string ("top-list-range");
                        query_parameters.append(@"topRange=$top_list_range&");
                    }

                    if (this.settings.get_boolean ("color-enabled")) {
                        var color = this.settings.get_string ("color");
                        query_parameters.append (@"colors=$color&");
                    }

                    query_parameters.append(@"seed=$(this.seed)&");
                    query_parameters.append(@"page=$(this.current_page)&");

                    string query = this.settings.get_string("query");
                    query_parameters.append(@"q=$query");

                    url = @"https://wallhaven.cc/api/v1/search?$(query_parameters.str)";
                    break;
                default:
                    assert (url != null);
                    break;
            }

            Soup.Session session = new Soup.Session();
            Soup.Message msg = new Soup.Message("GET", url);
            msg.get_request_headers().append("X-API-Key", this.settings.get_string("api-key"));
            debug (msg.uri.to_string());

            try {
                Bytes response_body = yield session.send_and_read_async (msg, 0, null);
                debug ((string) response_body.get_data());
                Response resp = Json.gobject_from_data (typeof(Response), (string)response_body.get_data()) as Response;
                assert (resp != null);

                debug(@"$(resp.meta.total) results matched");

                if (resp.meta.seed != null) {
                    this.seed = resp.meta.seed;
                } else {
                    this.seed = "";
                }

                Wallpaper wp;
                if (resp.meta.total > 0) {
                    if (this.settings.get_string ("search-mode") == "query" && this.settings.get_string ("sort-by") == "random") {
                        wp = resp.data.first ();
                    } else {
                        if (this.current_total >= resp.meta.total) {
                            this.current_index = 0;
                            this.current_page = 1;
                            this.current_total = 0;
                        }
                        wp = resp.data.get ((int) this.current_index);
                        this.current_index++;
                        this.current_total++;
                        this.current_page = resp.meta.current_page;
                        if (this.current_index > 24) {
                            this.current_index = 0;
                            this.current_page++;
                        }
                    }

                    this.current_wallpaper = new Damask.Wallpaper () {
                        web_url = wp.url,
                        url = wp.path,
                        resolution = wp.resolution,
                        thumbnail_url = wp.thumbs.small,
                    };
                    return this.current_wallpaper;
                }
            } catch (Error e) {
                this.toast (_("Failed to get wallpaper: %s").printf(e.message));
                message (e.message);
            }
            return null;
        }

        public Adw.PreferencesPage? preferences () {
            return new PreferencesPage () as Adw.PreferencesPage;
        }
    }

    [GtkTemplate (ui = "/app/drey/Damask/sources/wallhaven.ui")]
    public class PreferencesPage : Adw.PreferencesPage {
        private Settings settings = new Settings(@"$(Constants.APP_ID).sources.wallhaven");
        [GtkChild] private unowned Gtk.Entry username;
        [GtkChild] private unowned Gtk.Entry api_key;
        [GtkChild] private unowned Gtk.Entry query;
        [GtkChild] private unowned Gtk.CheckButton search_mode_query;
        [GtkChild] private unowned Adw.ComboRow collections;
        [GtkChild] private unowned Gtk.CheckButton search_mode_collections;
        [GtkChild] private unowned Adw.ComboRow sort_by;
        [GtkChild] private unowned Adw.ComboRow sort_order;
        [GtkChild] private unowned Adw.ComboRow top_list_range;
        [GtkChild] private unowned Gtk.Switch category_general;
        [GtkChild] private unowned Gtk.Switch category_anime;
        [GtkChild] private unowned Gtk.Switch category_people;
        [GtkChild] private unowned Gtk.Switch purity_sfw;
        [GtkChild] private unowned Gtk.Switch purity_sketchy;
        [GtkChild] private unowned Gtk.Switch purity_nsfw;
        [GtkChild] private unowned Gtk.Switch color_enabled;
        [GtkChild] private unowned Gtk.Button color_button;
        [GtkChild] private unowned Gtk.Popover color_popover;
        [GtkChild] private unowned Gtk.Button syntax_help;

        construct {
            debug (@"[%p] $(this.get_type().name()).construct", this);
            this.settings.bind ("username", username, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind("api-key", api_key, "text", SettingsBindFlags.DEFAULT);
            this.settings.bind("query", query, "text", SettingsBindFlags.DEFAULT);

            this.search_mode_query.active = this.settings.get_string("search-mode") == "query";
            this.search_mode_query.toggled.connect ((button) => {
                this.settings.set_string("search-mode", "query");
            });

            this.collections.expression = new Gtk.PropertyExpression (typeof(Collection), null, "label");
            this.collections.sensitive = this.settings.get_string("username").length > 0;
            this.settings.changed["username"].connect ((key) => {
                this.collections.sensitive = this.settings.get_string (key).length > 0;
            });

            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("GET", "https://wallhaven.cc/api/v1/collections");
            msg.get_request_headers().append("X-API-Key", this.settings.get_string("api-key"));
            session.send_and_read_async.begin (msg, 0, null, (source, result) => {
                try {
                    Bytes response_body = session.send_and_read_async.end (result);
                    debug ((string) response_body.get_data());
                    CollectionList resp = Json.gobject_from_data (typeof(CollectionList), (string)response_body.get_data ()) as CollectionList;
                    assert (resp != null);

                    ListStore list = new ListStore (typeof(Collection));
                    resp.data.foreach ((collection) => {
                        debug (@"adding collection $(collection.label)");
                        list.append (collection);
                        return true;
                    });
                    this.collections.model = list;
                    for (uint i = 0; i < list.get_n_items (); i++) {
                        Collection collection = list.get_object (i) as Collection;
                        if (this.settings.get_uint ("collection-id") == collection.id) {
                            this.collections.selected = i;
                        }
                    }
                    this.collections.notify["selected-item"].connect ((pspec) => {
                        Collection collection = collections.get_selected_item () as Collection;
                        if (this.settings.get_uint ("collection-id") != collection.id) {
                            message (@"selected collection $(collection.label)");
                            this.settings.set_uint ("collection-id", collection.id);
                        }
                    });
                } catch (Error e) {
                    message (e.message);
                }
            });

            this.search_mode_collections.active = this.settings.get_string("search-mode") == "collections";
            this.search_mode_collections.toggled.connect ((button) => {
                this.settings.set_string ("search-mode", "collections");
            });

            this.sort_by.selected = this.settings.get_enum ("sort-by");
            this.sort_by.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("sort-by", (int) this.sort_by.selected);
            });

            this.settings.bind("sort-order", sort_order, "selected", SettingsBindFlags.DEFAULT);

            this.top_list_range.selected = this.settings.get_enum ("top-list-range");
            this.top_list_range.sensitive = this.settings.get_string ("sort-by") == "toplist";
            this.top_list_range.notify["selected"].connect ((pspec) => {
                this.settings.set_enum ("top-list-range", (int) top_list_range.selected);
            });
            this.settings.changed["sort-by"].connect ((key) => {
                this.top_list_range.sensitive = this.settings.get_string (key) == "toplist";
            });

            this.settings.bind("category-general", category_general, "active", SettingsBindFlags.DEFAULT);
            this.settings.bind("category-anime", category_anime, "active", SettingsBindFlags.DEFAULT);
            this.settings.bind("category-people", category_people, "active", SettingsBindFlags.DEFAULT);

            this.settings.bind("purity-sfw", purity_sfw, "active", SettingsBindFlags.DEFAULT);
            this.settings.bind("purity-sketchy", purity_sketchy, "active", SettingsBindFlags.DEFAULT);
            this.settings.bind("purity-nsfw", purity_nsfw, "active", SettingsBindFlags.DEFAULT);
            this.purity_nsfw.sensitive = this.settings.get_string("api-key").length > 0;
            this.settings.changed["api-key"].connect ((key) => {
                this.purity_nsfw.sensitive = this.settings.get_string(key).length > 0;
            });

            this.settings.bind("color-enabled", color_enabled, "active", SettingsBindFlags.DEFAULT);

            var colors = new Gee.ArrayList<Gee.ArrayList<string>> ();
            colors.add (new Gee.ArrayList<string>.wrap ({ "660000", "990000", "cc0000", "cc3333", "ea4c88" }));
            colors.add (new Gee.ArrayList<string>.wrap ({ "993399", "663399", "333399", "0066cc", "0099cc" }));
            colors.add (new Gee.ArrayList<string>.wrap ({ "66cccc", "77cc33", "669900", "336600", "666600" }));
            colors.add (new Gee.ArrayList<string>.wrap ({ "999900", "cccc33", "ffff00", "ffcc33", "ff9900" }));
            colors.add (new Gee.ArrayList<string>.wrap ({ "ff6600", "cc6633", "996633", "663300", "000000" }));
            colors.add (new Gee.ArrayList<string>.wrap ({ "999999", "cccccc", "ffffff", "424153" }));

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.homogeneous = true;
            box.spacing = 8;
            foreach (Gee.ArrayList<string> row in colors) {
                var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                row_box.homogeneous = row.size == 5;
                row_box.spacing = 8;
                foreach (string color in row) {
                    var button = new Gtk.Button ();
                    button.name = @"$color";
                    button.clicked.connect (this.color_swatch_button_clicked);
                    button.css_classes = { "opaque", @"color_$(color)" };
                    row_box.append (button);
                }
                box.append (row_box);
            }
            this.color_popover.child = box;
            var color = this.settings.get_string ("color");
            this.color_button.css_classes = { "opaque", @"color_$color" };
            this.color_button.clicked.connect (this.color_button_clicked);

            this.syntax_help.clicked.connect (() => {
                SyntaxExample[] examples = {
                    { _("<tt>tagname</tt>"), _("search fuzzily for a tag/keyword") },
                    { _("<tt>-tagname</tt>"), _("exclude a tag/keyword") },
                    { _("<tt>+tag1 +tag2</tt>"), _("must have tag1 and tag2") },
                    { _("<tt>+tag1 -tag2</tt>"), _("must have tag1 and NOT tag2") },
                    { _("<tt>@username</tt>"), _("user uploads") },
                    { _("<tt>id:123</tt>"), _("Exact tag search (can not be combined)") },
                    { _("<tt>type:{png/jpg}</tt>"), _("Search for file type (jpg = jpeg)") },
                    { _("<tt>like:wallpaper ID</tt>"), _("Find wallpapers with similar tags") }
                };

                Gtk.Box query_example = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                Gtk.Box example_examples = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                Gtk.Box example_descriptions = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                foreach (SyntaxExample example in examples) {
                    Gtk.Label syntax_label = new Gtk.Label (example.example);
                    syntax_label.use_markup = true;
                    syntax_label.halign = Gtk.Align.START;

                    Gtk.Label syntax_description = new Gtk.Label (example.description);
                    syntax_description.halign = Gtk.Align.START;
                    syntax_description.add_css_class ("dim-label");

                    example_examples.append (syntax_label);
                    example_descriptions.append (syntax_description);
                }
                query_example.append (example_examples);
                query_example.append (example_descriptions);

                Gtk.Popover popover = new Gtk.Popover ();
                popover.child = query_example;
                popover.set_parent (syntax_help);
                popover.popup ();
            });
        }

        public void color_button_clicked () {
            this.color_popover.popup ();
        }

        public void color_swatch_button_clicked (Gtk.Button button) {
            message (button.name);
            this.settings.set_string ("color", @"$(button.name)");
            this.color_button.css_classes = { "opaque", @"color_$(button.name)" };
            this.color_popover.popdown ();
        }

        ~PreferencesPage () {
            debug (@"[%p] ~$(this.get_type().name())", this);
        }
    }
}
