// Custom Story / Custom Node Flowchart runtime helpers.
// Hybrid build: Node Process owns the graph; IceFrost Custom Episodes owns story playback.
global.custom_story_integration_installed = true;

// Injected into an existing GlobalScript CodeEntry so legacy VSML does not need
// to create a brand-new script resource.

global.custom_story_is_active = function()
{
    return variable_global_exists("custom_story_mode") && global.custom_story_mode == true;
};

global.custom_story_root = function()
{
    return working_directory + "custom_story/";
};

global.custom_story_field = function(arg0, arg1, arg2 = undefined)
{
    if (is_struct(arg0) && variable_struct_exists(arg0, arg1))
        return variable_struct_get(arg0, arg1);
    return arg2;
};

global.custom_story_read_json = function(arg0)
{
    if (!file_exists(arg0))
    {
        debug("[CustomStory] Missing file: " + string(arg0));
        return undefined;
    }

    var _fd = file_text_open_read(arg0);
    var _raw = "";

    while (!file_text_eof(_fd))
        _raw += file_text_readln(_fd);

    file_text_close(_fd);

    try
    {
        return json_parse(_raw);
    }
    catch (_err)
    {
        debug("[CustomStory] JSON parse error in " + string(arg0) + ": " + string(_err));
        show_message("Custom Story JSON parse error:\n" + string(arg0) + "\n\n" + string(_err));
        return undefined;
    }
};

global.custom_story_enter_mode = function()
{
    var _node_file = global.custom_story_root() + "nodes.json";

    if (!file_exists(_node_file))
    {
        show_message("Custom Episodes: custom_story/nodes.json was not found next to data.");
        return false;
    }

    if (!global.custom_story_is_active())
    {
        if (variable_global_exists("unlocked_event_nodes"))
            global.custom_story_saved_unlocked = global.unlocked_event_nodes;

        global.custom_story_last_node = -1;
    }

    global.custom_story_mode = true;
    global.custom_story_pending_leave = false;
    return true;
};

global.custom_story_leave_mode = function()
{
    var _was_custom = global.custom_story_is_active() || (variable_global_exists("custom_story_pending_leave") && global.custom_story_pending_leave);

    if (_was_custom && variable_global_exists("custom_story_saved_unlocked") && is_array(global.custom_story_saved_unlocked))
        global.unlocked_event_nodes = global.custom_story_saved_unlocked;

    // Do not let a snapshot from an old custom session overwrite later vanilla progress.
    global.custom_story_saved_unlocked = undefined;
    global.custom_story_mode = false;
    global.custom_story_pending_leave = false;
    global.custom_story_current_file = "";
    global.custom_story_bgm_name = "__unset__";
    global.custom_story_bgm_fade_old = -1;
    global.custom_story_bgm_cleanup_frames = 0;
};

global.custom_story_get_sprite = function(arg0)
{
    // arg0 may be an in-data asset name or a path relative to custom_story/.
    if (!is_string(arg0) || arg0 == "")
        return -1;

    var _asset = asset_get_index(arg0);
    if (_asset != -1)
        return _asset;

    var _path = global.custom_story_root() + arg0;
    if (!file_exists(_path))
    {
        debug("[CustomStory] Sprite not found: " + string(arg0));
        return -1;
    }

    if (!variable_global_exists("custom_story_sprite_cache") || !is_struct(global.custom_story_sprite_cache))
        global.custom_story_sprite_cache = {};

    if (variable_struct_exists(global.custom_story_sprite_cache, arg0))
        return variable_struct_get(global.custom_story_sprite_cache, arg0);

    var _spr = sprite_add(_path, 1, false, false, 0, 0);
    variable_struct_set(global.custom_story_sprite_cache, arg0, _spr);
    return _spr;
};

// Prefer the current layout, then fall back to the original episode folder.
// Return paths relative to custom_story/ so image/audio/video bases stay intact.
global.custom_story_resolve_file = function(arg0)
{
    var _file = string_replace_all(string(arg0), "\\", "/");
    var _legacy = "../Custom Episodes/";
    if (string_pos(_legacy, _file) == 1)
        _file = "episodes/" + string_delete(_file, 1, string_length(_legacy));

    if (file_exists(global.custom_story_root() + _file)) return _file;
    if (string_pos("episodes/", _file) == 1)
    {
        var _old = _legacy + string_delete(_file, 1, string_length("episodes/"));
        if (file_exists(global.custom_story_root() + _old)) return _old;
    }
    return _file;
};

// Old episodes need no nodes.json entries: append them after configured nodes.
global.custom_story_add_legacy_nodes = function(arg0, arg1)
{
    var _defs = arg0;
    var _seen = {};
    var _ids = {};
    var _row = 0;
    for (var _i = 0; _i < array_length(_defs); _i++)
    {
        var _def = _defs[_i];
        variable_struct_set(_ids, string(global.custom_story_field(_def, "id", "node_" + string(_i))), true);
        var _file = global.custom_story_resolve_file(global.custom_story_field(_def, "story", ""));
        variable_struct_set(_seen, _file, true);
        _row = max(_row, real(global.custom_story_field(_def, "y", 0)));
    }

    var _root = working_directory + "Custom Episodes/";
    var _folders = [];
    // Finish the directory search before opening JSON files.
    var _name = file_find_first(_root + "*", 16);
    while (_name != "")
    {
        if (_name != "." && _name != ".." && directory_exists(_root + _name))
            array_push(_folders, _name);
        _name = file_find_next();
    }
    file_find_close();
    array_sort(_folders, true);

    var _added = 0;
    for (var _i = 0; _i < array_length(_folders); _i++)
    {
        var _folder = _folders[_i];
        var _file = global.custom_story_resolve_file("episodes/" + _folder + "/story.json");
        if (variable_struct_exists(_seen, _file)) continue;
        if (!file_exists(global.custom_story_root() + _file)) continue;
        var _data = global.custom_story_read_json(global.custom_story_root() + _file);
        if (!is_struct(_data) || !is_array(global.custom_story_field(_data, "lines", undefined))) continue;

        var _id = "legacy_" + _folder;
        while (variable_struct_exists(_ids, _id)) _id += "_";
        variable_struct_set(_ids, _id, true);
        variable_struct_set(_seen, _file, true);
        array_push(_defs, {
            id: _id, chapter: arg1, x: 8 + (_added * 4), y: _row + 4,
            episode: string(global.custom_story_field(_data, "episode_name", "CUSTOM")),
            title: string(global.custom_story_field(_data, "title", _folder)),
            description: global.custom_story_field(_data, "description", ""),
            story: _file, requires: []
        });
        _added++;
    }
    return _defs;
};

global.custom_story_load_nodes = function()
{
    if (!instance_exists(o_mod_storyentry))
        instance_create_depth(0, 0, -999999, o_mod_storyentry);

    var _config = global.custom_story_root() + "nodes.json";
    var _doc = file_exists(_config)
        ? global.custom_story_read_json(_config)
        : { title: "Custom Episodes", nodes: [] };
    global.event_nodes = [];
    global.story_events = [];
    global.custom_story_chapters = [];
    global.custom_story_chapter_map = {};

    if (_doc == undefined || !is_struct(_doc))
    {
        show_message("Custom Episodes: nodes.json could not be loaded.");
        global.custom_story_chapters[0] = {
            id: "error", origin_x: 160, origin_y: 610,
            background: "flow1", background_x: 136, background_y: 594,
            background_xscale: 1, background_yscale: 1, background_alpha: 1,
            bgm: "flowloop_1_true", bgm_fade_ms: 350, hud_frame: 1
        };
        global.event_nodes[0] = {
            base: 1, x: 160, y: 610, type: 1, story: "__custom_error__",
            truecost: 0, cost: 0, prereq: [], nav_override: {}, cam: {x: 0, y: 0},
            info_above: false, custom_story: true, custom_story_file: "stories/error.json",
            custom_story_id: "__custom_error__", custom_episode: "CUSTOM ERROR",
            custom_story_chapter: 0, custom_story_bgm: "flowloop_1_true", custom_story_bgm_fade_ms: 350,
            custom_story_underlay: "", custom_story_underlay_x: 0, custom_story_underlay_y: 0,
            custom_story_underlay_xscale: 1, custom_story_underlay_yscale: 1, custom_story_underlay_alpha: 1
        };
        global.story_events[0] = {
            story_id: "__custom_error__", ep_name: "CUSTOM ERROR", ep_title: "nodes.json failed",
            desc_1: "Fix custom_story/nodes.json", desc_2: "and reopen Node Flowchart.",
            content_alert: false, content_1: "", content_2: ""
        };
        global.unlocked_event_nodes = [true];
        global.has_seen_warnings = [true];
        global.custom_story_last_node = 0;
        return;
    }

    global.custom_story_title = string(global.custom_story_field(_doc, "title", "Custom Episodes"));
    var _grid = real(global.custom_story_field(_doc, "grid", 30));
    if (_grid <= 0) _grid = 30;
    var _default_bgm = string(global.custom_story_field(_doc, "default_bgm", global.custom_story_field(_doc, "flow_bgm", "")));
    var _default_fade = real(global.custom_story_field(_doc, "bgm_fade_ms", 350));
    if (_default_fade < 0) _default_fade = 0;

    // Chapters are the stock Node Process "base" concept: each has its own
    // origin, flow background and HUD frame.  BGM here is only a default;
    // the actually selected node may override it.
    var _chapters = global.custom_story_field(_doc, "chapters", []);
    if (!is_array(_chapters) || array_length(_chapters) <= 0)
    {
        var _legacy_origin = global.custom_story_field(_doc, "origin", [160, 610]);
        var _legacy_x = 160;
        var _legacy_y = 610;
        if (is_array(_legacy_origin))
        {
            if (array_length(_legacy_origin) > 0) _legacy_x = real(_legacy_origin[0]);
            if (array_length(_legacy_origin) > 1) _legacy_y = real(_legacy_origin[1]);
        }
        _chapters = [{
            id: "default", origin: [_legacy_x, _legacy_y],
            background: "flow1", background_position: [_legacy_x - 24, _legacy_y - 16],
            bgm: _default_bgm, bgm_fade_ms: _default_fade, hud_frame: 1
        }];
    }

    for (var _c = 0; _c < array_length(_chapters); _c++)
    {
        var _src_ch = _chapters[_c];
        var _cid = string(global.custom_story_field(_src_ch, "id", "chapter_" + string(_c + 1)));
        var _origin = global.custom_story_field(_src_ch, "origin", [160 + (_c * 770), 610]);
        var _ox = 160 + (_c * 770);
        var _oy = 610;
        if (is_array(_origin))
        {
            if (array_length(_origin) > 0) _ox = real(_origin[0]);
            if (array_length(_origin) > 1) _oy = real(_origin[1]);
        }

        var _bg = string(global.custom_story_field(_src_ch, "background", ""));
        var _bgx = _ox;
        var _bgy = _oy;
        var _bgpos = global.custom_story_field(_src_ch, "background_position", undefined);
        if (is_array(_bgpos))
        {
            if (array_length(_bgpos) > 0) _bgx = real(_bgpos[0]);
            if (array_length(_bgpos) > 1) _bgy = real(_bgpos[1]);
        }
        else
        {
            var _bgoff = global.custom_story_field(_src_ch, "background_offset", [0, 0]);
            if (is_array(_bgoff))
            {
                if (array_length(_bgoff) > 0) _bgx += real(_bgoff[0]);
                if (array_length(_bgoff) > 1) _bgy += real(_bgoff[1]);
            }
        }

        var _scale = global.custom_story_field(_src_ch, "background_scale", [1, 1]);
        var _sx = 1;
        var _sy = 1;
        if (is_array(_scale))
        {
            if (array_length(_scale) > 0) _sx = real(_scale[0]);
            if (array_length(_scale) > 1) _sy = real(_scale[1]);
        }
        else if (is_real(_scale))
        {
            _sx = _scale;
            _sy = _scale;
        }

        var _ch_bgm = _default_bgm;
        if (variable_struct_exists(_src_ch, "bgm"))
            _ch_bgm = string(_src_ch.bgm);
        var _ch_fade = real(global.custom_story_field(_src_ch, "bgm_fade_ms", _default_fade));
        if (_ch_fade < 0) _ch_fade = 0;

        global.custom_story_chapters[_c] = {
            id: _cid,
            origin_x: _ox,
            origin_y: _oy,
            background: _bg,
            background_x: _bgx,
            background_y: _bgy,
            background_xscale: _sx,
            background_yscale: _sy,
            background_alpha: real(global.custom_story_field(_src_ch, "background_alpha", 1)),
            bgm: _ch_bgm,
            bgm_fade_ms: _ch_fade,
            hud_frame: real(global.custom_story_field(_src_ch, "hud_frame", _c + 1))
        };
        variable_struct_set(global.custom_story_chapter_map, _cid, _c);
    }

    var _defs = global.custom_story_field(_doc, "nodes", []);
    if (!is_array(_defs)) _defs = [];
    _defs = global.custom_story_add_legacy_nodes(_defs, global.custom_story_chapters[0].id);
    if (array_length(_defs) <= 0)
    {
        show_message("Custom Episodes: nodes.json contains no nodes.");
        _defs = [{ id: "empty", chapter: global.custom_story_chapters[0].id, x: 0, y: 0, episode: "CUSTOM", title: "No nodes", story: "stories/error.json" }];
    }

    var _id_map = {};

    // Pass 1: allocate nodes and build id -> array-index map.
    for (var _i = 0; _i < array_length(_defs); _i++)
    {
        var _src = _defs[_i];
        var _id = string(global.custom_story_field(_src, "id", "node_" + string(_i)));
        variable_struct_set(_id_map, _id, _i);

        var _chapter_id = string(global.custom_story_field(_src, "chapter", global.custom_story_chapters[0].id));
        var _chapter_index = variable_struct_exists(global.custom_story_chapter_map, _chapter_id) ? variable_struct_get(global.custom_story_chapter_map, _chapter_id) : 0;
        if (!variable_struct_exists(global.custom_story_chapter_map, _chapter_id))
            debug("[CustomStory] Unknown chapter '" + _chapter_id + "' on node " + _id + "; using first chapter.");
        var _chapter = global.custom_story_chapters[_chapter_index];

        var _episode = string(global.custom_story_field(_src, "episode", "CUSTOM " + string(_i + 1)));
        var _title = string(global.custom_story_field(_src, "title", _id));
        var _desc1 = "";
        var _desc2 = "";
        var _desc = global.custom_story_field(_src, "description", []);

        if (is_array(_desc))
        {
            if (array_length(_desc) > 0) _desc1 = string(_desc[0]);
            if (array_length(_desc) > 1) _desc2 = string(_desc[1]);
        }
        else if (_desc != undefined)
        {
            _desc1 = string(_desc);
        }

        var _cam = { x: 0, y: 0 };
        var _src_cam = global.custom_story_field(_src, "camera", undefined);
        if (is_struct(_src_cam))
        {
            _cam.x = real(global.custom_story_field(_src_cam, "x", 0));
            _cam.y = real(global.custom_story_field(_src_cam, "y", 0));
        }

        // Node BGM wins.  Otherwise inherit the chapter default.  Empty string
        // is an intentional "fade to silence" value.
        var _node_bgm = _chapter.bgm;
        if (variable_struct_exists(_src, "bgm"))
            _node_bgm = string(_src.bgm);
        var _node_fade = real(global.custom_story_field(_src, "bgm_fade_ms", _chapter.bgm_fade_ms));
        if (_node_fade < 0) _node_fade = 0;

        var _underlay = "";
        var _underlay_x = 0;
        var _underlay_y = 0;
        var _underlay_sx = 1;
        var _underlay_sy = 1;
        var _underlay_alpha = 1;
        var _ul = global.custom_story_field(_src, "underlay", undefined);
        if (is_string(_ul))
        {
            _underlay = _ul;
        }
        else if (is_struct(_ul))
        {
            _underlay = string(global.custom_story_field(_ul, "asset", global.custom_story_field(_ul, "file", "")));
            var _off = global.custom_story_field(_ul, "offset", [0, 0]);
            if (is_array(_off))
            {
                if (array_length(_off) > 0) _underlay_x = real(_off[0]);
                if (array_length(_off) > 1) _underlay_y = real(_off[1]);
            }
            var _us = global.custom_story_field(_ul, "scale", [1, 1]);
            if (is_array(_us))
            {
                if (array_length(_us) > 0) _underlay_sx = real(_us[0]);
                if (array_length(_us) > 1) _underlay_sy = real(_us[1]);
            }
            else if (is_real(_us))
            {
                _underlay_sx = _us;
                _underlay_sy = _us;
            }
            _underlay_alpha = real(global.custom_story_field(_ul, "alpha", 1));
        }

        var _node = {
            base: _chapter_index + 1,
            x: _chapter.origin_x + (_grid * real(global.custom_story_field(_src, "x", 0))),
            y: _chapter.origin_y + (_grid * real(global.custom_story_field(_src, "y", 0))),
            type: 1,
            story: _id,
            truecost: 0,
            cost: 0,
            prereq: [],
            nav_override: {},
            cam: _cam,
            info_above: global.custom_story_field(_src, "info_above", false) == true,
            custom_story: true,
            custom_story_id: _id,
            custom_story_file: global.custom_story_resolve_file(global.custom_story_field(_src, "story", "stories/" + _id + ".json")),
            custom_episode: _episode,
            custom_story_chapter: _chapter_index,
            custom_story_bgm: _node_bgm,
            custom_story_bgm_fade_ms: _node_fade,
            custom_story_underlay: _underlay,
            custom_story_underlay_x: _underlay_x,
            custom_story_underlay_y: _underlay_y,
            custom_story_underlay_xscale: _underlay_sx,
            custom_story_underlay_yscale: _underlay_sy,
            custom_story_underlay_alpha: _underlay_alpha
        };

        global.event_nodes[_i] = _node;
        global.story_events[_i] = {
            story_id: _id,
            ep_name: _episode,
            ep_title: _title,
            desc_1: _desc1,
            desc_2: _desc2,
            content_alert: false,
            content_1: "",
            content_2: ""
        };
    }

    // Pass 2: resolve graph edges and optional directional navigation by node id.
    for (var _i = 0; _i < array_length(_defs); _i++)
    {
        var _src = _defs[_i];
        var _node = global.event_nodes[_i];
        var _requires = global.custom_story_field(_src, "requires", []);

        if (is_array(_requires))
        {
            for (var _r = 0; _r < array_length(_requires); _r++)
            {
                var _rid = string(_requires[_r]);
                if (variable_struct_exists(_id_map, _rid))
                    array_push(_node.prereq, variable_struct_get(_id_map, _rid));
                else
                    debug("[CustomStory] Unknown prerequisite '" + _rid + "' on node " + _node.custom_story_id);
            }
        }

        var _nav = global.custom_story_field(_src, "nav", undefined);
        if (is_struct(_nav))
        {
            var _dirs = ["left", "right", "up", "down"];
            for (var _d = 0; _d < array_length(_dirs); _d++)
            {
                var _dir = _dirs[_d];
                if (variable_struct_exists(_nav, _dir))
                {
                    var _dest_id = string(variable_struct_get(_nav, _dir));
                    if (variable_struct_exists(_id_map, _dest_id))
                        variable_struct_set(_node.nav_override, _dir, variable_struct_get(_id_map, _dest_id));
                    else
                        debug("[CustomStory] Unknown nav target '" + _dest_id + "' on node " + _node.custom_story_id);
                }
            }
        }
    }

    global.unlocked_event_nodes = array_create(array_length(global.event_nodes), true);
    global.has_seen_warnings = array_create(array_length(global.event_nodes), true);

    var _start_id = string(global.custom_story_field(_doc, "start", global.event_nodes[0].custom_story_id));
    var _start_index = 0;
    if (variable_struct_exists(_id_map, _start_id))
        _start_index = variable_struct_get(_id_map, _start_id);

    if (!variable_global_exists("custom_story_last_node") || global.custom_story_last_node < 0 || global.custom_story_last_node >= array_length(global.event_nodes))
        global.custom_story_last_node = _start_index;

    // Fresh room, fresh selector-music manager state.
    global.custom_story_bgm_name = "__unset__";
    global.custom_story_bgm_fade_old = -1;
    global.custom_story_bgm_cleanup_frames = 0;
};


global.custom_story_nodes_connected = function(arg0, arg1)
{
    if (arg0 == arg1) return false;
    var _a = nodes[arg0].node;
    var _b = nodes[arg1].node;

    for (var _i = 0; _i < array_length(_a.prereq); _i++)
        if (_a.prereq[_i] == arg1) return true;

    for (var _i = 0; _i < array_length(_b.prereq); _i++)
        if (_b.prereq[_i] == arg0) return true;

    return false;
};

global.custom_story_navigate = function(arg0)
{
    if (array_length(nodes) <= 1) return;

    var _cur = nodes[current_node].node;
    var _next = -1;

    if (variable_struct_exists(_cur, "nav_override") && variable_struct_exists(_cur.nav_override, arg0))
        _next = real(variable_struct_get(_cur.nav_override, arg0));

    if (_next < 0 || _next >= array_length(nodes))
    {
        _next = -1;
        var _best = 1000000000;

        // Prefer graph-connected candidates; fall back to any node in that direction.
        for (var _pass = 0; _pass < 2 && _next == -1; _pass++)
        {
            _best = 1000000000;
            for (var _i = 0; _i < array_length(nodes); _i++)
            {
                if (_i == current_node || !nodes[_i].visible) continue;
                if (_pass == 0 && !global.custom_story_nodes_connected(current_node, _i)) continue;

                var _dx = nodes[_i].node.x - _cur.x;
                var _dy = nodes[_i].node.y - _cur.y;
                var _valid = false;
                var _score = 0;

                switch (arg0)
                {
                    case "left":
                        _valid = _dx < 0;
                        _score = abs(_dx) + (abs(_dy) * 2);
                        break;
                    case "right":
                        _valid = _dx > 0;
                        _score = abs(_dx) + (abs(_dy) * 2);
                        break;
                    case "up":
                        _valid = _dy < 0;
                        _score = abs(_dy) + (abs(_dx) * 2);
                        break;
                    case "down":
                        _valid = _dy > 0;
                        _score = abs(_dy) + (abs(_dx) * 2);
                        break;
                }

                if (_valid && _score < _best)
                {
                    _best = _score;
                    _next = _i;
                }
            }
        }
    }

    if (_next >= 0 && _next < array_length(nodes))
    {
        pressing = false;
        with (camera) node_speed = 1;
        current_node = _next;
        event_user(0);
    }
};


// -------------------------------------------------------------------------
// Node-selection BGM crossfade.
// The stock play_bgm() hard-stops global.bgm, which is exactly what we do NOT
// want while moving the cursor.  Keep the outgoing instance alive until its
// gain ramp reaches zero, while the newly selected node fades in.
// -------------------------------------------------------------------------

global.custom_story_bgm_cleanup = function()
{
    if (!variable_global_exists("custom_story_bgm_cleanup_frames"))
        global.custom_story_bgm_cleanup_frames = 0;
    if (!variable_global_exists("custom_story_bgm_fade_old"))
        global.custom_story_bgm_fade_old = -1;

    if (global.custom_story_bgm_cleanup_frames > 0)
    {
        global.custom_story_bgm_cleanup_frames--;
        if (global.custom_story_bgm_cleanup_frames <= 0)
        {
            var _old = global.custom_story_bgm_fade_old;
            if (_old != -1 && (!variable_global_exists("bgm") || _old != global.bgm) && audio_is_playing(_old))
                audio_stop_sound(_old);
            global.custom_story_bgm_fade_old = -1;
        }
    }
};

global.custom_story_switch_bgm = function(arg0, arg1 = 350)
{
    var _name = string(arg0);
    var _fade = max(0, real(arg1));

    if (!variable_global_exists("custom_story_bgm_name"))
        global.custom_story_bgm_name = "__unset__";
    if (!variable_global_exists("custom_story_bgm_fade_old"))
        global.custom_story_bgm_fade_old = -1;
    if (!variable_global_exists("custom_story_bgm_cleanup_frames"))
        global.custom_story_bgm_cleanup_frames = 0;

    // Same musical target and a live handle: do not restart it.
    if (_name == global.custom_story_bgm_name && variable_global_exists("bgm") && global.bgm != -1 && audio_is_playing(global.bgm))
        return;

    var _asset = -1;
    if (_name != "")
    {
        _asset = asset_get_index(_name);
        if (_asset == -1)
        {
            debug("[CustomStory] Node BGM asset not found: " + _name);
            return;
        }
    }

    var _old = -1;
    var _position = 0;
    if (variable_global_exists("bgm") && global.bgm != -1 && audio_is_playing(global.bgm))
    {
        _old = global.bgm;
        _position = audio_sound_get_track_position(_old);
    }

    // Match NodeFlowBGM's rapid-reversal rule: never keep more than the
    // current loop plus one fading loop alive.
    if (global.custom_story_bgm_fade_old != -1 && global.custom_story_bgm_fade_old != _old && audio_is_playing(global.custom_story_bgm_fade_old))
        audio_stop_sound(global.custom_story_bgm_fade_old);

    global.custom_story_bgm_name = _name;

    if (_name == "")
    {
        if (_old != -1 && audio_is_playing(_old))
        {
            audio_sound_gain(_old, 0, _fade);
            global.custom_story_bgm_fade_old = _old;
            global.custom_story_bgm_cleanup_frames = ceil((room_speed * _fade) / 1000) + 2;
        }
        else
        {
            global.custom_story_bgm_fade_old = -1;
            global.custom_story_bgm_cleanup_frames = 0;
        }
        global.bgm = -1;
        debug("[CustomStory] Selected node requests silence (fade " + string(_fade) + "ms).");
        return;
    }

    // The stock flowloops are authored as a shared timeline. Preserve the
    // outgoing track position exactly like the supplied NodeFlowBGM reference.
    var _target_length = audio_sound_length(_asset);
    if (_target_length > 0)
        _position = _position mod _target_length;

    var _new = audio_play_sound(_asset, 1, true, 0);
    if (_position > 0)
        audio_sound_set_track_position(_new, _position);

    // Vanilla Node Flowchart uses 3 * op_bgm_volume for these loops.
    audio_sound_gain(_new, 3 * global.op_bgm_volume, _fade);

    if (_old != -1 && audio_is_playing(_old))
    {
        audio_sound_gain(_old, 0, _fade);
        global.custom_story_bgm_fade_old = _old;
        global.custom_story_bgm_cleanup_frames = ceil((room_speed * _fade) / 1000) + 2;
    }
    else
    {
        global.custom_story_bgm_fade_old = -1;
        global.custom_story_bgm_cleanup_frames = 0;
    }

    global.bgm = _new;
    debug("[CustomStory] Synced crossfade -> " + _name + " @ " + string(_position) + "s (" + string(_fade) + "ms)");
};

global.custom_story_select_node = function(arg0)
{
    if (!global.custom_story_is_active())
        return;
    if (!is_array(global.event_nodes) || arg0 < 0 || arg0 >= array_length(global.event_nodes))
        return;

    var _node = global.event_nodes[arg0];
    var _bgm = variable_struct_exists(_node, "custom_story_bgm") ? _node.custom_story_bgm : "";
    var _fade = variable_struct_exists(_node, "custom_story_bgm_fade_ms") ? _node.custom_story_bgm_fade_ms : 350;
    global.custom_story_switch_bgm(_bgm, _fade);
};


global.custom_story_eventline_step = function()
{
    global.custom_story_bgm_cleanup();
    if (!enabled) return;

    if (input_check_pressed(11)) global.custom_story_navigate("left");
    if (input_check_pressed(12)) global.custom_story_navigate("right");
    if (input_check_pressed(13)) global.custom_story_navigate("up");
    if (input_check_pressed(14)) global.custom_story_navigate("down");

    if (input_check_pressed(4))
        pressing = true;

    if (input_check_released(4) && !transitioning && pressing)
    {
        pressing = false;
        global.custom_story_last_node = current_node;
        var _node = nodes[current_node].node;
        start_story_node(_node);
    }

    if (input_check_pressed(5) && !transitioning)
    {
        global.custom_story_last_node = current_node;
        global.custom_story_pending_leave = true;
        audio_stop_all();
        play_se(sfx_songsel_beginsong);
        transitioning = true;
        var _transition = instance_create_depth(view_wport[0] / 2, view_hport[0] / 2, -1000, o_transition_diamond);

        with (_transition)
        {
            TweenEasyFade(0, 1, 0, 60, EaseOutQuint);
            TweenEasyRotate(-45, 315, 0, 60, EaseOutExpo);
            TweenEasyScale(1, 1, 320, 180, 0, 60, EaseOutQuad);
            next_room = scene_mainmenu;
            alarm[0] = 60;
        }

        enabled = false;
    }

    camera_set_view_pos(view_camera[0], camera.x, camera.y);
};

global.custom_story_draw_edge_segment = function(arg0, arg1, arg2, arg3, arg4, arg5, arg6)
{
    // Axis-aligned filled strip.  Custom story graph connections deliberately
    // do not use diagonal primitives: horizontal/vertical rectangles stay
    // pixel-clean on the game's 320x180 logical canvas.
    var _x1 = arg0;
    var _y1 = arg1;
    var _x2 = arg2;
    var _y2 = arg3;
    var _width = max(1, arg4);
    var _colour = arg5;
    var _alpha = arg6;
    var _half = _width * 0.5;

    draw_set_color(_colour);
    draw_set_alpha(_alpha);

    if (abs(_y2 - _y1) <= 0.001)
    {
        draw_rectangle(min(_x1, _x2), _y1 - _half,
                       max(_x1, _x2), _y1 + _half, false);
        return;
    }

    if (abs(_x2 - _x1) <= 0.001)
    {
        draw_rectangle(_x1 - _half, min(_y1, _y2),
                       _x1 + _half, max(_y1, _y2), false);
    }
};


global.custom_story_draw_edge = function(arg0, arg1, arg2, arg3, arg4, arg5, arg6)
{
    // Orthogonal Node Process routing only.  Same-row / same-column edges are
    // one straight segment.  Otherwise leave the parent vertically first and
    // then turn exactly 90 degrees into the child horizontally:
    //
    //     parent
    //       |
    //       +--------- child
    //
    // The two filled rectangles overlap at the elbow, so there is no corner
    // gap and, critically, no diagonal rasterization at all.
    var _x1 = arg0;
    var _y1 = arg1;
    var _x2 = arg2;
    var _y2 = arg3;
    var _width = arg4;
    var _colour = arg5;
    var _alpha = arg6;

    if (abs(_y2 - _y1) <= 0.001 || abs(_x2 - _x1) <= 0.001)
    {
        global.custom_story_draw_edge_segment(
            _x1, _y1, _x2, _y2,
            _width, _colour, _alpha
        );
        return;
    }

    // V -> H gives a natural left-to-right flowchart branch: the wire leaves
    // the parent from its top/bottom edge, then enters the child from the side.
    var _corner_x = _x1;
    var _corner_y = _y2;

    global.custom_story_draw_edge_segment(
        _x1, _y1, _corner_x, _corner_y,
        _width, _colour, _alpha
    );
    global.custom_story_draw_edge_segment(
        _corner_x, _corner_y, _x2, _y2,
        _width, _colour, _alpha
    );
};

global.custom_story_draw_flow = function()
{
    draw_set_default();

    // 1. Stock-style chapter/base backgrounds.
    if (variable_global_exists("custom_story_chapters") && is_array(global.custom_story_chapters))
    {
        for (var _c = 0; _c < array_length(global.custom_story_chapters); _c++)
        {
            var _ch = global.custom_story_chapters[_c];
            if (!is_struct(_ch) || _ch.background == "")
                continue;
            var _spr = global.custom_story_get_sprite(_ch.background);
            if (_spr != -1)
                draw_sprite_ext(_spr, 0, _ch.background_x, _ch.background_y, _ch.background_xscale, _ch.background_yscale, 0, c_white, _ch.background_alpha);
        }
    }

    // 2. Graph edges.  These are intentionally drawn BEFORE node-local
    // underlays.  A decorative plate attached to a node therefore sits over
    // the wire instead of having the wire scribbled across its face.
    for (var _n = 0; _n < array_length(o_eventline.nodes); _n++)
    {
        var _inst = o_eventline.nodes[_n];
        if (!_inst.visible)
            continue;

        var _node = _inst.node;
        for (var _i = 0; _i < array_length(_node.prereq); _i++)
        {
            var _parent_index = _node.prereq[_i];
            if (_parent_index < 0 || _parent_index >= array_length(o_eventline.nodes))
                continue;

            var _other = o_eventline.nodes[_parent_index];
            if (!_other.visible)
                continue;

            var _do_red = (_node.type == 3 || _other.node.type == 3);
            global.custom_story_draw_edge(
                _other.x - 1, _other.y,
                _inst.x - 1, _inst.y,
                2,
                _do_red ? c_red : c_black,
                0.5
            );
        }
    }

    // 3. Optional node-local underlays.  They cover the line underneath them,
    // while o_eventnode itself is drawn later at its normal depth.
    for (var _n = 0; _n < array_length(o_eventline.nodes); _n++)
    {
        var _inst = o_eventline.nodes[_n];
        if (!_inst.visible)
            continue;
        var _node = _inst.node;
        if (variable_struct_exists(_node, "custom_story_underlay") && _node.custom_story_underlay != "")
        {
            var _under = global.custom_story_get_sprite(_node.custom_story_underlay);
            if (_under != -1)
                draw_sprite_ext(_under, 0,
                    _inst.x + _node.custom_story_underlay_x,
                    _inst.y + _node.custom_story_underlay_y,
                    _node.custom_story_underlay_xscale,
                    _node.custom_story_underlay_yscale,
                    0, c_white, _node.custom_story_underlay_alpha);
        }
    }

    draw_set_alpha(1);
    draw_set_color(c_white);
};

// Story playback intentionally ends here in the hybrid build.
// o_cutsceneConductor is handed to the IceFrost Custom Episodes coroutine runtime
// instead of the older explicit `commands` state machine.
