// Custom Story Node Process entry.
// This intentionally mirrors BVS's TAB + System Options entry:
//     if (keyboard_check(vk_tab)) { ... } else { ... }
// Here the modifier is Shift instead of Tab.
debug("[CustomStory] Node Flowchart activate; keyboard_check(vk_shift)=" + string(keyboard_check(vk_shift)));

if (keyboard_check(vk_shift))
{
    // Snapshot the vanilla node-unlock array once, before custom flow replaces it.
    if (!(variable_global_exists("custom_story_mode") && global.custom_story_mode == true))
    {
        if (variable_global_exists("unlocked_event_nodes") && is_array(global.unlocked_event_nodes))
            global.custom_story_saved_unlocked = global.unlocked_event_nodes;
        else
            global.custom_story_saved_unlocked = undefined;
    }

    global.custom_story_mode = true;
    global.custom_story_pending_leave = false;
    global.custom_story_last_node = -1;
    debug("[CustomStory] Shift modifier accepted; entering custom Node Flowchart.");
}
else
{
    // Plain Node Flowchart must remain vanilla.
    if (variable_global_exists("custom_story_leave_mode"))
        global.custom_story_leave_mode();
    else
    {
        if (variable_global_exists("custom_story_saved_unlocked") && is_array(global.custom_story_saved_unlocked))
            global.unlocked_event_nodes = global.custom_story_saved_unlocked;

        global.custom_story_saved_unlocked = undefined;
        global.custom_story_mode = false;
        global.custom_story_pending_leave = false;
    }

    debug("[CustomStory] No Shift modifier; entering vanilla Node Flowchart.");
}

// Always enter the real eventline scene. Loading custom files happens there.
transitionToScene(scene_eventline, true, 4);
