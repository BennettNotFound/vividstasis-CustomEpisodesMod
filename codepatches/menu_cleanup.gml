// Ensure the IceFrost story runtime exists before the user can enter custom nodes.
if (!instance_exists(o_mod_storyentry))
    instance_create_depth(0, 0, -999999, o_mod_storyentry);

// A custom flow may reach the menu through pause/other exits; restore vanilla node state here.
if ((variable_global_exists("custom_story_mode") && global.custom_story_mode == true) || (variable_global_exists("custom_story_pending_leave") && global.custom_story_pending_leave))
{
    if (variable_global_exists("custom_story_leave_mode"))
        global.custom_story_leave_mode();
    else
        global.custom_story_mode = false;
}
