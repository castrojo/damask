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
        private static Gee.ArrayList<string> sort_by = new Gee.ArrayList<string>.wrap ({ "date_added", "relevance", "random", "views", "favorites", "top_list" });
        private static Gee.ArrayList<string> top_list_range = new Gee.ArrayList<string>.wrap ({ "1d", "3d", "1w", "1M", "3M", "6M", "1y" });

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
            });
        }

        public string title {
            get { return "Wallhaven"; }
        }

        public string subtitle {
            get { return "Get wallpapers from wallhaven.cc"; }
        }

        private Damask.Wallpaper? _current_wallpaper;
        public Damask.Wallpaper? current_wallpaper {
            get { return _current_wallpaper; }
        }

        public void refresh () {
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
                              aspect = "4∶3";
                              break;
                            case 16:
                              aspect = "16∶10";
                              break;
                            case 17:
                              aspect = "16∶9";
                              break;
                            case 23:
                              aspect = "21∶9";
                              break;
                            case 12:
                              aspect = "5∶4";
                              break;
                              /* This catches 1.5625 as well (1600x1024) when maybe it shouldn't. */
                            case 15:
                              aspect = "3∶2";
                              break;
                            case 18:
                              aspect = "9∶5";
                              break;
                            case 10:
                              aspect = "1∶1";
                              break;
                        }
                        query_parameters.append(@"ratios=$aspect&");
                    }

                    string sorting = this.settings.get_string("sort-by");
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
                        Gdk.RGBA rgba = Gdk.RGBA ();
                        if (rgba.parse (this.settings.get_string ("color"))) {
                            StringBuilder color_string = new StringBuilder ();
                            color_string.append_printf ("%02X%02X%02X", (int) (rgba.red * 255), (int) (rgba.green * 255), (int) (rgba.blue * 255));
                            query_parameters.append(@"colors=$(color_string.str)&");
                        }
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

            session.send_and_read_async.begin (msg, 0, null, (source, result) => {
                try {
                    Bytes response_body = session.send_and_read_async.end(result);
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
                        this._current_wallpaper = new Damask.Wallpaper ();
                        this._current_wallpaper.web_url = wp.url;
                        this._current_wallpaper.url = wp.path;
                        this._current_wallpaper.title = wp.url;
                        this._current_wallpaper.resolution = wp.resolution;
                        this._current_wallpaper.thumbnail_url = wp.thumbs.small;
                        this.changed(wp.path);
                    }
                } catch (Error e) {
                    print ("cannot deserialize from data: %s\n", e.message);
                }
            });
        }

        public Adw.PreferencesPage? prefs () {
            Gtk.Builder builder = new Gtk.Builder.from_resource (@"$(Constants.RESOURCE_PATH_PREFIX)/sources/wallhaven.ui");
            Adw.PreferencesPage prefs = builder.get_object("prefs") as Adw.PreferencesPage;

            Gtk.Entry username = builder.get_object("username") as Gtk.Entry;
            this.settings.bind("username", username, "text", SettingsBindFlags.DEFAULT);

            Gtk.Entry api_key = builder.get_object("api_key") as Gtk.Entry;
            this.settings.bind("api-key", api_key, "text", SettingsBindFlags.DEFAULT);

            Gtk.Entry query = builder.get_object("query") as Gtk.Entry;
            this.settings.bind("query", query, "text", SettingsBindFlags.DEFAULT);

            Gtk.CheckButton search_mode_query = builder.get_object("search_mode_query") as Gtk.CheckButton;
            search_mode_query.active = this.settings.get_string("search-mode") == "query";
            search_mode_query.toggled.connect ((button) => {
                this.settings.set_string("search-mode", "query");
            });

            Adw.ComboRow collections = builder.get_object("collections") as Adw.ComboRow;
            collections.expression = new Gtk.PropertyExpression (typeof(Collection), null, "label");
            collections.sensitive = this.settings.get_string("username").length > 0;
            this.settings.changed["username"].connect ((key) => {
                collections.sensitive = this.settings.get_string(key).length > 0;
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
                    collections.model = list;
                    for (uint i = 0; i < list.get_n_items (); i++) {
                        Collection collection = list.get_object (i) as Collection;
                        if (this.settings.get_uint ("collection-id") == collection.id) {
                            collections.selected = i;
                        }
                    }
                    collections.notify["selected-item"].connect ((pspec) => {
                        Collection collection = collections.get_selected_item () as Collection;
                        if (this.settings.get_uint("collection-id") != collection.id) {
                            message (@"selected collection $(collection.label)");
                            this.settings.set_uint("collection-id", collection.id);
                        }
                    });
                } catch (Error e) {
                    print ("cannot deserialize from data: %s\n", e.message);
                }
            });

            Gtk.CheckButton search_mode_collections = builder.get_object("search_mode_collections") as Gtk.CheckButton;
            search_mode_collections.active = this.settings.get_string("search-mode") == "collections";
            search_mode_collections.toggled.connect ((button) => {
                this.settings.set_string("search-mode", "collections");
            });

            Adw.ComboRow sort_by = builder.get_object("sort_by") as Adw.ComboRow;
            sort_by.selected = Wallhaven.sort_by.index_of (this.settings.get_string ("sort-by"));
            sort_by.notify["selected"].connect ((pspec) => {
                this.settings.set_string ("sort-by", Wallhaven.sort_by.get ((int) sort_by.selected));
            });

            Adw.ComboRow sort_order = builder.get_object("sort_order") as Adw.ComboRow;
            this.settings.bind("sort-order", sort_order, "selected", SettingsBindFlags.DEFAULT);

            Adw.ComboRow top_list_range = builder.get_object("top_list_range") as Adw.ComboRow;
            top_list_range.selected = Wallhaven.top_list_range.index_of (this.settings.get_string ("top-list-range"));
            top_list_range.notify["selected"].connect ((pspec) => {
                this.settings.set_string ("top-list-range", Wallhaven.top_list_range.get ((int) top_list_range.selected));
            });

            Gtk.Switch category_general = builder.get_object("category_general") as Gtk.Switch;
            this.settings.bind("category-general", category_general, "state", SettingsBindFlags.DEFAULT);

            Gtk.Switch category_anime = builder.get_object("category_anime") as Gtk.Switch;
            this.settings.bind("category-anime", category_anime, "state", SettingsBindFlags.DEFAULT);

            Gtk.Switch category_people = builder.get_object("category_people") as Gtk.Switch;
            this.settings.bind("category-people", category_people, "state", SettingsBindFlags.DEFAULT);

            Gtk.Switch purity_sfw = builder.get_object("purity_sfw") as Gtk.Switch;
            this.settings.bind("purity-sfw", purity_sfw, "state", SettingsBindFlags.DEFAULT);

            Gtk.Switch purity_sketchy = builder.get_object("purity_sketchy") as Gtk.Switch;
            this.settings.bind("purity-sketchy", purity_sketchy, "state", SettingsBindFlags.DEFAULT);

            Gtk.Switch purity_nsfw = builder.get_object("purity_nsfw") as Gtk.Switch;
            this.settings.bind("purity-nsfw", purity_nsfw, "state", SettingsBindFlags.DEFAULT);

            top_list_range.sensitive = this.settings.get_string ("sort-by") == "top_list";
            this.settings.changed["sort-by"].connect ((key) => {
                top_list_range.sensitive = this.settings.get_string (key) == "top_list";
            });

            Gtk.Switch color_enabled = builder.get_object("color_enabled") as Gtk.Switch;
            this.settings.bind("color-enabled", color_enabled, "state", SettingsBindFlags.DEFAULT);

            Gtk.ColorButton color = builder.get_object("color") as Gtk.ColorButton;
            {
                Gdk.RGBA rgba = Gdk.RGBA ();
                if (rgba.parse (this.settings.get_string ("color"))) {
                    color.rgba = rgba;
                }
            }
            const Gdk.RGBA[] palette = {
                { 0.400000f, 0.000000f, 0.000000f }, // #660000
                { 0.600000f, 0.000000f, 0.000000f }, // #990000
                { 0.800000f, 0.000000f, 0.000000f }, // #cc0000
                { 0.800000f, 0.200000f, 0.200000f }, // #cc3333
                { 0.917647f, 0.298039f, 0.533333f }, // #ea4c88
                { 0.600000f, 0.200000f, 0.600000f }, // #993399
                { 0.400000f, 0.200000f, 0.600000f }, // #663399
                { 0.200000f, 0.200000f, 0.600000f }, // #333399
                { 0.000000f, 0.400000f, 0.800000f }, // #0066cc
                { 0.000000f, 0.600000f, 0.800000f }, // #0099cc
                { 0.400000f, 0.800000f, 0.800000f }, // #66cccc
                { 0.466667f, 0.800000f, 0.200000f }, // #77cc33
                { 0.400000f, 0.600000f, 0.000000f }, // #669900
                { 0.200000f, 0.400000f, 0.000000f }, // #336600
                { 0.400000f, 0.400000f, 0.000000f }, // #666600
                { 0.600000f, 0.600000f, 0.000000f }, // #999900
                { 0.800000f, 0.800000f, 0.200000f }, // #cccc33
                { 1.000000f, 1.000000f, 0.000000f }, // #ffff00
                { 1.000000f, 0.800000f, 0.200000f }, // #ffcc33
                { 1.000000f, 0.600000f, 0.000000f }, // #ff9900
                { 1.000000f, 0.400000f, 0.000000f }, // #ff6600
                { 0.800000f, 0.400000f, 0.200000f }, // #cc6633
                { 0.600000f, 0.400000f, 0.200000f }, // #996633
                { 0.400000f, 0.200000f, 0.000000f }, // #663300
                { 0.000000f, 0.000000f, 0.000000f }, // #000000
                { 0.600000f, 0.600000f, 0.600000f }, // #999999
                { 0.800000f, 0.800000f, 0.800000f }, // #cccccc
                { 1.000000f, 1.000000f, 1.000000f }, // #ffffff
                { 0.258824f, 0.254902f, 0.325490f }, // #424153
            };
            color.add_palette (Gtk.Orientation.HORIZONTAL, 5, palette);
            color.color_set.connect (() => {
                Gdk.RGBA rgba = color.get_rgba ();
                this.settings.set_string ("color", rgba.to_string ());
            });

            Gtk.Button syntax_help = builder.get_object("syntax_help") as Gtk.Button;
            syntax_help.clicked.connect (() => {
                const SyntaxExample[] examples = {
                    { "<tt>tagname</tt>", "search fuzzily for a tag/keyword" },
                    { "<tt>-tagname</tt>", "exclude a tag/keyword" },
                    { "<tt>+tag1 +tag2</tt>", "must have tag1 and tag2" },
                    { "<tt>+tag1 -tag2</tt>", "must have tag1 and NOT tag2" },
                    { "<tt>@username</tt>", "user uploads" },
                    { "<tt>id:123</tt>", "Exact tag search (can not be combined)" },
                    { "<tt>type:{png/jpg}</tt>", "Search for file type (jpg = jpeg)" },
                    { "<tt>like:wallpaper ID</tt>", "Find wallpapers with similar tags" }
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

            return prefs;
        }
    }
}
