// o_mod_storyentry -- persistent story/chart runtime service.
// Node Flowchart owns entry and navigation; story playback runs as a coroutine.

// Finish a release that mod_cs_end() deferred: by now the room has changed, so the
// story room's o_bg / portraits - the only things that pointed at the external
// sprites - are gone.
if (global.mod_cs_release_pending && room != scene_story)
{
    // Natural node-story endings now spend 60 frames inside scene_story while
    // o_transition_diamond closes. Keep external sprites/streams alive until the
    // destination room has actually replaced the story room.
    global.mod_cs_release_pending = false;
    mod_cs_log("step: pending release (room=" + string(room) + ")");
    mod_cs_release_episode();
}

// In-chart stories (the "custom_episode" gimmick). A chart has no story
// coroutine, so the request, the playback and the cleanup all run from here; the
// runner stops itself when the song or the room goes away. See the Create event.
mod_cs_chart_tick();

// Track room changes: leaving scene_story while an episode is running means the
// session is over - either the story finished, or the player left through the pause
// menu, which cancels the coroutine and never runs our own cleanup.
var _room_now = room;
var _room_changed = (_room_now != mcs_last_room);
mcs_last_room = _room_now;

if (mode == 1 && _room_changed && _room_now != scene_story)
{
    // Leaving the story room ends this playback session.
    var _was_active = global.mod_cs_active;
    mode = 0;
    menu_open = false;
    menu_lock_key = true;
    global.mod_cs_active = false;
    global.mod_cs_pending = undefined;
    // The stock pause menu leaves global.story_paused set when it exits a story.
    global.story_paused = false;
    mod_cs_restore_globals();
    mod_cs_movie_stop();
    // Leaving through the pause menu skips mod_cs_end(), so the HD state has to be
    // undone here too: obj_resolution_handler is persistent and would otherwise
    // keep rendering the main menu at the multiplier the episode switched on.
    mod_cs_release_episode();
    if (instance_exists(obj_storyportrait))
    {
        with (obj_storyportrait) instance_destroy();
    }
    if (textbox_exists())
    {
        text_clear();
        destroy_textbox();
    }

    // Keep the legacy fallback scoped away from custom node sessions.
    if (_was_active && _room_now == scene_eventline
        && !(variable_global_exists("custom_story_mode") && global.custom_story_mode == true))
    {
        room_goto(scene_mainmenu);
    }
}

if (mode == 1)
{
    // Current vivid/stasis builds suppress the stock story-pause path during
    // some auto-advancing cutscene states. Our JSON coroutine contains those
    // states too (bg/tint/move/fade etc.), so ESC could work on the opening text
    // and then mysteriously stop working once the real story began.
    //
    // For node-integrated stories, provide a narrow fallback: pause the exact
    // coroutine owned by o_cutsceneConductor and open the game's own o_story_pause
    // menu. If stock code already opened it this frame, instance_exists() makes
    // this a no-op. Resume/Exit are therefore still handled by vanilla code.
    if (_room_now == scene_story
        && global.mod_cs_active
        && variable_global_exists("custom_story_mode") && global.custom_story_mode == true
        && !instance_exists(o_story_pause)
        && (input_check_pressed(5) || keyboard_check_pressed(vk_escape)))
    {
        if (instance_exists(o_cutsceneConductor))
        {
            with (o_cutsceneConductor)
            {
                if (!is_undefined(coroutine) && is_struct(coroutine))
                    coroutine.Pause();
            }
        }
        global.story_paused = true;
        instance_create_depth(0, 0, -10000, o_story_pause);
    }

    // Playback is otherwise driven by the game's coroutine manager.
    exit;
}

