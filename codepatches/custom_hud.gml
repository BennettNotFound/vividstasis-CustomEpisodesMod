if (variable_global_exists("custom_story_mode") && global.custom_story_mode == true)
{
    var _frame = 1;
    if (current_node >= 0 && current_node < array_length(nodes))
    {
        var _ni = nodes[current_node].node;
        if (variable_struct_exists(_ni, "custom_story_chapter") && variable_global_exists("custom_story_chapters"))
        {
            var _ci = _ni.custom_story_chapter;
            if (_ci >= 0 && _ci < array_length(global.custom_story_chapters))
                _frame = global.custom_story_chapters[_ci].hud_frame;
        }
    }

    draw_sprite(sp_eventline_hud, _frame, 0, 0);
    draw_set_default();
    draw_set_font(global.default_font);
    draw_set_color(c_white);
    draw_set_halign(fa_right);
    draw_text(313, 2, "Custom Episodes " + string(current_node + 1) + "/" + string(array_length(nodes)));
    draw_set_halign(fa_left);
    exit;
}

draw_sprite(sp_eventline_hud, get_nodeflow_chapter(current_node), 0, 0);
