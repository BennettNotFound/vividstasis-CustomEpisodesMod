if ((variable_global_exists("custom_story_mode") && global.custom_story_mode == true))
{
    if (variable_global_exists("custom_story_draw_flow"))
        global.custom_story_draw_flow();
    exit;
}

draw_set_default();
