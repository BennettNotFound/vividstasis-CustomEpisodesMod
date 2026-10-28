if (variable_global_exists("custom_story_mode") && global.custom_story_mode == true)
{
    if (!instance_exists(o_mod_storyentry))
        instance_create_depth(0, 0, -999999, o_mod_storyentry);

    if (variable_global_exists("mod_cs_run_node_story"))
        coroutine = global.mod_cs_run_node_story();
    else
        coroutine = undefined;
}
else
{
    coroutine = script_execute(global.load_scene);
}
