if (variable_global_exists("custom_story_mode") && global.custom_story_mode == true)
{
    // Custom nodes are all unlocked by their sandbox array.  Do not exit here:
    // the rest of the stock user event computes the correct sprite frame.
    node_enabled = true;
}
