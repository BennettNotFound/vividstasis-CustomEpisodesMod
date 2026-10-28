if ((variable_global_exists("custom_story_mode") && global.custom_story_mode == true))
{
    if (variable_global_exists("custom_story_eventline_step"))
        global.custom_story_eventline_step();
    exit;
}

if (!enabled)
    exit;
