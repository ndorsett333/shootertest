pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--init

function _init()
  -- player ship position
  player_x = 60  -- center horizontally (128/2 - 4)
  player_y = 110 -- right above player stats bar
  player_speed = 2 -- movement speed
  
  -- bullet system
  bullets = {}
  bullet_speed = 4
  
  -- shooting cooldown
  fire_cooldown = 0
  fire_delay = 10  -- frames between shots
  fire_button_was_pressed = false  -- track previous button state
  
  -- enemy system
  enemy_x = 60  -- center
  enemy_y = 8   -- top of screen
  enemy_speed = 1.25
  enemy_dir = 1   -- direction: 1 = right, -1 = left
  enemy_change_timer = 0  -- timer for direction changes
  enemy_health = 4
  enemy_defeated = false
  enemy_hit_timer = 0
  enemy_hit_delay = 30
  
  -- enemy shooting system
  enemy_bullets = {}
  enemy_bullet_speed = 2
  enemy_shoot_timer = 0
  enemy_shoot_delay_min = 15
  enemy_shoot_delay_max = 45
  enemy_last_x = 60  -- track enemy's previous position for path crossing
  
  -- set initial enemy shoot timer
  enemy_shoot_timer = enemy_shoot_delay_min + rnd(enemy_shoot_delay_max - enemy_shoot_delay_min)
  
  -- rock obstacle system
  rocks = {}
  rock_speed = 0.5 
  rock_spawn_timer = 0
  rock_spawn_delay_min = 30  
  rock_spawn_delay_max = 90  
  
  -- set initial spawn timer
  rock_spawn_timer = rock_spawn_delay_min + rnd(rock_spawn_delay_max - rock_spawn_delay_min)
  
  -- spawn rocks
  for i = 1, 5 do
    local rock_type = rnd()
    local rock_x = 20 + i * 20
    
    if rock_type < 0.5 then
      -- single rock 6 or 7
      local sprite_choice = rnd() > 0.5 and 6 or 7
      add(rocks, {
        x = rock_x,
        y = 40 + rnd(48),
        sprite = sprite_choice
      })
    else
      -- long rock 22 and 23
      local rock_y = 40 + rnd(48)
      add(rocks, {
        x = rock_x,
        y = rock_y,
        sprite = 22,
        is_long = true,
        partner_id = #rocks + 2
      })
      add(rocks, {
        x = rock_x + 8,
        y = rock_y,
        sprite = 23,
        is_long = true,
        partner_id = #rocks
      })
    end
  end
  
  -- victory system
  victory_timer = 0
  victory_delay = 45
  victory_triggered = false
  
  -- player lives
  player_lives = 3 
  player_hit_timer = 0 
  player_hit_delay = 60
  
  -- player death
  player_death_timer = 0
  player_death_delay = 45
  player_death_triggered = false
  player_death_flash_timer = 0  -- timer for death sprite flashing
  
  -- enemy death flash timer
  enemy_death_flash_timer = 0
  
  -- game state system
  game_state = "playing"
  
  -- power-up select system
  powerup_select_timer = 0
  powerup_select_delay = 90  -- frames to wait
  selected_powerup = 1
  max_powerup = 3
  powerup_select_confirmed = false
  powerup_confirm_timer = 0
  powerup_confirm_delay = 60
  
  -- power-up names
  powerup_options = {
    "Extra Life",
    "Increase Speed",
    "Increase Fire"
  }
  
  -- power-up vars
  powerup_extra_life = false
  powerup_increase_speed = false
  powerup_increase_fire_speed = false
  
  -- level select system
  level_select_timer = 0
  level_select_delay = 90  -- timer
  selected_level = 1
  max_level = 3  -- total levels
  current_level = 0  -- (0 = starting level)
  level_select_confirmed = false
  level_confirm_timer = 0
  level_confirm_delay = 60
  
  -- star system names
  star_systems = {
    "Zephyros Prime",
    "Nexar Cluster", 
    "Vortani Reach"
  }
  
  -- completed levels
  completed_levels = {}
  
  -- debug: add a stationary laser right above player to see alignment
  --[[
  add(bullets, {
    x = player_x,  -- exactly at player x position
    y = player_y - 8,  -- just above player sprite
    debug = true  -- mark as debug so it doesn't move
  })
  --]]
  
  -- start music
  music(0)
end




-->8
--update

function _update()
  -- power-up select controls
  if game_state == "powerup_select" then
    -- auto-adjust for already taken
    while selected_powerup <= max_powerup and 
          ((selected_powerup == 1 and powerup_extra_life) or
           (selected_powerup == 2 and powerup_increase_speed) or
           (selected_powerup == 3 and powerup_increase_fire_speed)) do
      selected_powerup = selected_powerup + 1
    end
    -- if all powerups taken, wrap to first available
    if selected_powerup > max_powerup then
      selected_powerup = 1
      while selected_powerup <= max_powerup and 
            ((selected_powerup == 1 and powerup_extra_life) or
             (selected_powerup == 2 and powerup_increase_speed) or
             (selected_powerup == 3 and powerup_increase_fire_speed)) do
        selected_powerup = selected_powerup + 1
      end
    end
    
    if btnp(2) then -- up arrow
      local original = selected_powerup
      repeat
        selected_powerup = selected_powerup - 1
        if selected_powerup < 1 then
          selected_powerup = max_powerup
        end
      until not ((selected_powerup == 1 and powerup_extra_life) or
                  (selected_powerup == 2 and powerup_increase_speed) or
                  (selected_powerup == 3 and powerup_increase_fire_speed)) or selected_powerup == original
      if selected_powerup ~= original then
        sfx(20)
      end
    end
    if btnp(3) then -- down arrow
      local original = selected_powerup
      repeat
        selected_powerup = selected_powerup + 1
        if selected_powerup > max_powerup then
          selected_powerup = 1
        end
      until not ((selected_powerup == 1 and powerup_extra_life) or
                  (selected_powerup == 2 and powerup_increase_speed) or
                  (selected_powerup == 3 and powerup_increase_fire_speed)) or selected_powerup == original
      if selected_powerup ~= original then
        sfx(20)
      end
    end
    if btnp(5) then
      if not powerup_select_confirmed then
        powerup_select_confirmed = true
        powerup_confirm_timer = powerup_confirm_delay
        sfx(21)
      end
    end
    if powerup_select_confirmed then
      powerup_confirm_timer = powerup_confirm_timer - 1
      if powerup_confirm_timer <= 0 then
        -- activate power-up
        if selected_powerup == 1 then
          powerup_extra_life = true
        elseif selected_powerup == 2 then
          powerup_increase_speed = true
        elseif selected_powerup == 3 then
          powerup_increase_fire_speed = true
        end
        
        -- transition to level select
        game_state = "level_select"
        powerup_select_confirmed = false -- reset confirmation state
      end
    end
    return
  end

  -- level select controls
  if game_state == "level_select" then
    
    while selected_level <= max_level and completed_levels[selected_level] do
      selected_level = selected_level + 1
    end
    
    if selected_level > max_level then
      selected_level = 1
      while selected_level <= max_level and completed_levels[selected_level] do
        selected_level = selected_level + 1
      end
    end
    
    if btnp(2) then -- up arrow
      local original = selected_level
      repeat
        selected_level = selected_level - 1
        if selected_level < 1 then
          selected_level = max_level
        end
      until not completed_levels[selected_level] or selected_level == original
      if selected_level ~= original then
        sfx(20)
      end
    end
    if btnp(3) then  
      local original = selected_level
      repeat
        selected_level = selected_level + 1
        if selected_level > max_level then
          selected_level = 1
        end
      until not completed_levels[selected_level] or selected_level == original
      if selected_level ~= original then
        sfx(20)
      end
    end
    if btnp(5) then -- select level
      if not level_select_confirmed then
        level_select_confirmed = true
        level_confirm_timer = level_confirm_delay
        sfx(21) 
      end
    end
    if level_select_confirmed then
      level_confirm_timer = level_confirm_timer - 1
      if level_confirm_timer <= 0 then
        current_level = selected_level
        -- reset game state
        game_state = "playing"
        enemy_defeated = false
        enemy_health = 4
        victory_triggered = false
        victory_timer = 0
        level_select_timer = 0
        level_select_confirmed = false
        
        if powerup_extra_life then
          player_lives = 4
        else
          player_lives = 3
        end
        player_hit_timer = 0
        player_death_timer = 0
        player_death_triggered = false
        bullets = {}
        enemy_bullets = {}
        music(0) -- restart music
      end
    end
    return
  end
  
  -- player movement controls
  if not enemy_defeated and player_lives > 0 then
    
    -- determine player speed based on power-up
    local current_speed = player_speed
    if powerup_increase_speed then
      current_speed = player_speed * 2  -- 100% speed increase
    end
    
    if btn(0) then -- left arrow
      player_x = player_x - current_speed
    end
    if btn(1) then -- right arrow
      player_x = player_x + current_speed
    end
    
    -- keep player on screen
    if player_x < 0 then
      player_x = 0
    end
    if player_x > 120 then -- 128 - 8 (sprite width)
      player_x = 120
    end
  end
  
  -- update fire cooldown
  if fire_cooldown > 0 then
    fire_cooldown = fire_cooldown - 1
  end
  
  -- update player hit timer (invincibility frames)
  if player_hit_timer > 0 then
    player_hit_timer = player_hit_timer - 1
  end
  
  -- update enemy hit timer
  if enemy_hit_timer > 0 then
    enemy_hit_timer = enemy_hit_timer - 1
  end
  
  -- shooting
  local fire_button_pressed = btn(5)
  if fire_button_pressed and not fire_button_was_pressed and fire_cooldown <= 0 and not enemy_defeated and player_lives > 0 then
    -- play laser sound
    sfx(2)
    
    -- determine fire delay and bullet count based on power-up
    local current_fire_delay = fire_delay
    if powerup_increase_fire_speed then
      current_fire_delay = fire_delay / 2  -- half the delay (twice as fast)
      
      -- create dual beams
      add(bullets, {
        x = player_x - 2, -- left beam
        y = player_y - 8
      })
      add(bullets, {
        x = player_x + 2, -- right beam  
        y = player_y - 8
      })
    else
      -- create single bullet at player position
      add(bullets, {
        x = player_x,
        y = player_y - 8
      })
    end
    
    -- set cooldown based on power-up
    fire_cooldown = current_fire_delay
  end
  fire_button_was_pressed = fire_button_pressed
  
  -- update bullets
  for bullet in all(bullets) do
    -- only move non-debug bullets
    if not bullet.debug then
      bullet.y = bullet.y - bullet_speed
      
      -- check collision with enemy (if not defeated)
      
      if not enemy_defeated and 
         bullet.x < enemy_x + 8 and bullet.x + 8 > enemy_x and
         bullet.y < enemy_y + 8 and bullet.y + 8 > enemy_y then
        -- enemy hit sound
        sfx(0)
        
        -- enemy takes damage
        enemy_health = enemy_health - 1
        enemy_hit_timer = enemy_hit_delay -- start hit flash timer
        del(bullets, bullet)
        
        -- check if enemy is defeated
        if enemy_health <= 0 then
          enemy_defeated = true
          music(-1) -- stop music
          sfx(3) -- enemy death sound only
          victory_timer = victory_delay
          enemy_death_flash_timer = 0 -- reset flash timer
          
          -- mark level as completed
          if current_level > 0 then
            completed_levels[current_level] = true
          end
          
          -- clear all enemy bullets
          enemy_bullets = {}
        end
        break -- exit since bullet is destroyed
      end
      
      -- check hit rocks
      for rock in all(rocks) do
        
        if bullet.x < rock.x + 8 and bullet.x + 8 > rock.x and
           bullet.y < rock.y + 8 and bullet.y + 8 > rock.y then
          -- destroy bullet when if rock
          del(bullets, bullet)
          break -- exit rock loop since bullet is destroyed
        end
      end
      
      -- remove bullets that go off screen
      if bullet.y < -8 then
        del(bullets, bullet)
      end
    end
  end
  
  -- enemy AI - only move if not defeated and player is alive
  if not enemy_defeated and player_lives > 0 then
    enemy_change_timer = enemy_change_timer - 1
    
    -- randomly change direction every 60-120 frames
    if enemy_change_timer <= 0 then
      enemy_dir = rnd() > 0.5 and 1 or -1  -- randomly choose left or right
      enemy_change_timer = 60 + rnd(60)     -- reset timer to 60-120 frames
    end
    
    -- enemy speed based on current level
    local current_enemy_speed = enemy_speed
    if current_level > 0 then
      current_enemy_speed = enemy_speed * 1.75
    end
    
    -- move enemy in current direction
    enemy_x = enemy_x + (current_enemy_speed * enemy_dir)
    
    -- bounce off screen edges and change direction
    if enemy_x <= 0 then
      enemy_x = 0
      enemy_dir = 1  -- force right
      enemy_change_timer = 30 + rnd(30)  -- shorter timer after bouncing
    elseif enemy_x >= 120 then
      enemy_x = 120
      enemy_dir = -1  -- force left
      enemy_change_timer = 30 + rnd(30)  -- shorter timer after bouncing
    end
  end
  
  -- enemy shooting
  if not enemy_defeated and player_lives > 0 then
    enemy_shoot_timer = enemy_shoot_timer - 1
    
    -- check if enemy crosses player's path
    local crossed_path = false
    if (enemy_last_x < player_x and enemy_x >= player_x) or 
       (enemy_last_x > player_x and enemy_x <= player_x) then
      crossed_path = true
    end
    
    -- shoot if timer expires OR if crossing player's path
    if enemy_shoot_timer <= 0 or crossed_path then
      -- play enemy shoot sound
      sfx(1)
      
      -- create new bullet at enemy position
      add(enemy_bullets, {
        x = enemy_x + 4, -- center of enemy sprite
        y = enemy_y + 8  -- just below enemy sprite
      })
      
      -- determine fire delay based on current level
      local current_min_delay = enemy_shoot_delay_min
      local current_max_delay = enemy_shoot_delay_max
      if current_level > 0 then
        -- same faster firing for all levels 1-3
        current_min_delay = enemy_shoot_delay_min * 0.6  -- 40% faster firing
        current_max_delay = enemy_shoot_delay_max * 0.6
      end
      
      -- reset shoot timer with level-adjusted delay
      enemy_shoot_timer = current_min_delay + rnd(current_max_delay - current_min_delay)
    end
    
    -- store enemy position for next frame path detection
    enemy_last_x = enemy_x
  end
  
  -- update enemy bullets
  for bullet in all(enemy_bullets) do
    bullet.y = bullet.y + enemy_bullet_speed
    
    -- check collision with player
    if player_hit_timer <= 0 and player_lives > 0 and
       bullet.x < player_x + 8 and bullet.x + 8 > player_x and
       bullet.y < player_y + 8 and bullet.y + 8 > player_y then
      -- player hit by enemy bullet
      sfx(19)
      player_lives = player_lives - 1
      player_hit_timer = player_hit_delay -- start invincibility frames
      del(enemy_bullets, bullet)
      
      -- check if player is out of lives
      if player_lives <= 0 then
        music(-1)
        sfx(4) -- player death sound
        player_death_timer = player_death_delay
        player_death_flash_timer = 0 -- reset flash timer
        
        -- clear all bullets
        bullets = {}
        enemy_bullets = {}
      end
      break
    end
    
    -- check collision with rocks
    for rock in all(rocks) do
      if bullet.x < rock.x + 8 and bullet.x + 8 > rock.x and
         bullet.y < rock.y + 8 and bullet.y + 8 > rock.y then
        -- destroy bullet when it hits a rock
        del(enemy_bullets, bullet)
        break -- exit rock loop since bullet is destroyed
      end
    end
    
    -- remove bullets before player bar
    if bullet.y > 115 then
      del(enemy_bullets, bullet)
    end
  end
  
  if not enemy_defeated and player_lives > 0 then
    rock_spawn_timer = rock_spawn_timer - 1
    
    -- spawn new rock when timer expires
    if rock_spawn_timer <= 0 then
      local rock_type = rnd()
      
      if rock_type < 0.33 then
        -- single rock sprite 6
        add(rocks, {
          x = 128,
          y = 40 + rnd(48),
          sprite = 6
        })
      elseif rock_type < 0.66 then
        -- single rock sprite 7
        add(rocks, {
          x = 128,
          y = 40 + rnd(48),
          sprite = 7
        })
      else
        -- long rock (sprites 6 and 7 combined)
        local rock_y = 40 + rnd(48)
        add(rocks, {
          x = 128,
          y = rock_y,
          sprite = 22,
          is_long = true,
          partner_id = #rocks + 2 -- reference to the second part
        })
        add(rocks, {
          x = 136, -- 8 pixels to the right
          y = rock_y,
          sprite = 23,
          is_long = true,
          partner_id = #rocks -- reference to the first part
        })
      end
      
      -- reset spawn timer with random delay
      rock_spawn_timer = rock_spawn_delay_min + rnd(rock_spawn_delay_max - rock_spawn_delay_min)
    end
  end
  
  -- update rocks
  if not enemy_defeated and player_lives > 0 then
    for rock in all(rocks) do
      rock.x = rock.x - rock_speed
      
      -- remove rocks that go off left edge
      if rock.x < -8 then
        del(rocks, rock)
      end
    end
  end
  
  -- cheat code: hold up + X + O to win
  if btn(2) and btn(4) and btn(5) and not enemy_defeated then
    enemy_health = 0
    enemy_defeated = true
    music(-1) -- stop music
    sfx(3) -- enemy death sound only
    victory_timer = victory_delay
    enemy_death_flash_timer = 0 -- reset flash timer
    
    -- mark level as completed (but not starting level) - same as normal kill
    if current_level > 0 then
      completed_levels[current_level] = true
    end
    
    -- clear all enemy bullets - same as normal kill
    enemy_bullets = {}
  end
  
  -- victory timer system
  if enemy_defeated and victory_timer > 0 then
    victory_timer = victory_timer - 1
    
    -- play victory sound when timer reaches zero
    if victory_timer == 0 and not victory_triggered then
      sfx(5) -- victory sound
      victory_triggered = true
      -- start power up select timer
      powerup_select_timer = powerup_select_delay
    end
  end
  
  -- power up select timer system
  if enemy_defeated and victory_triggered and powerup_select_timer > 0 then
    powerup_select_timer = powerup_select_timer - 1
    
    -- show power up select when timer expires
    if powerup_select_timer == 0 then
      game_state = "powerup_select"
    end
  end
  
  -- level select timer system
  if enemy_defeated and victory_triggered and level_select_timer > 0 then
    level_select_timer = level_select_timer - 1
    
    -- show level select when timer expires
    if level_select_timer == 0 then
      game_state = "level_select"
    end
  end
  
  -- player death timer system
  if player_lives <= 0 and player_death_timer > 0 then
    player_death_timer = player_death_timer - 1
    
    -- play death sound
    if player_death_timer == 0 and not player_death_triggered then
      -- sfx(4)
      player_death_triggered = true
    end
  end
  
  -- death flash timers
  if player_lives <= 0 and player_death_timer > 0 then
    player_death_flash_timer = player_death_flash_timer + 1
  end
  
  if enemy_defeated and victory_timer > 0 then
    enemy_death_flash_timer = enemy_death_flash_timer + 1
  end
end
-->8
--draw

function _draw()
  -- clear screen
  cls()
  
  -- draw background map
  map(0, 0, 0, 0, 16, 16)
  
  -- draw health indicators based on enemy health
  for i = 1, enemy_health do
    -- draw health sprites at top of map (positions 0,0 1,0 2,0)
    spr(21, (i-1) * 8, 0) -- sprite 21 for health indicators
  end
  
  -- draw player lives
  for i = 1, player_lives do
    spr(18, (i-1) * 8, 120) -- sprite 18 for player life hearts
  end
  
  -- draw bullets
  for bullet in all(bullets) do
    spr(17, bullet.x, bullet.y) -- sprite #017
  end
  
  -- draw enemy bullets
  for bullet in all(enemy_bullets) do
    spr(16, bullet.x, bullet.y) -- sprite #16 (corrected from #18)
  end
  
  -- draw rocks
  for rock in all(rocks) do
    spr(rock.sprite, rock.x, rock.y)
  end
  
  -- draw enemy (sprite 2 or death flash if defeated)
  if enemy_defeated then
    -- only show enemy during victory timer
    if victory_timer > 0 then
      local enemy_sprite = 34  -- default death/explosion sprite
      
      -- flash between explosion sprite and empty sprite
      if (enemy_death_flash_timer % 8) < 4 then
        enemy_sprite = 0  -- empty/transparent sprite
      end
      
      spr(enemy_sprite, enemy_x, enemy_y)
    end
    -- after victory timer expires
  else
    -- choose enemy sprite based on current level
    local enemy_sprite = 2  -- default sprite
    if current_level == 1 then
      enemy_sprite = 35  -- Zephyros Prime
    elseif current_level == 2 then
      enemy_sprite = 36  -- Nexar Cluster
    elseif current_level == 3 then
      enemy_sprite = 37  -- Vortani Reach
    end
    
    -- flash between normal and hit sprite during hit timer
    if enemy_hit_timer > 0 then
      -- flash every 4 frames for visible effect
      if (enemy_hit_timer % 8) < 4 then
        enemy_sprite = 33  -- hit sprite
      end
    end
    
    spr(enemy_sprite, enemy_x, enemy_y)
  end
  
  -- draw player ship
  if player_lives <= 0 then
    
    if player_death_timer > 0 then
      local player_sprite = 34  -- default death sprite
      
      
      if (player_death_flash_timer % 8) < 4 then
        player_sprite = 0  -- empty/transparent sprite
      end
      
      spr(player_sprite, player_x, player_y)
    end
    -- after death timer expires, don't draw player
  else
    local player_sprite = 1  -- default sprite
    
    -- flash between normal and hit sprite during hit timer
    if player_hit_timer > 0 then
      -- flash every 4 frames
      if (player_hit_timer % 8) < 4 then
        player_sprite = 32  -- hit sprite
      end
    end
    
    spr(player_sprite, player_x, player_y)
  end
  
  -- draw win message only after victory timer expires
  if enemy_defeated and victory_timer == 0 then
    rectfill(35, 56, 85, 66, 1) 
    -- draw "You won!" text in the center of the screen
    print("You won!", 40, 60, 7) -- white text at center position
  end
  
  -- draw death message
  if player_lives <= 0 and player_death_timer == 0 then
    rectfill(35, 56, 85, 66, 1) 
    
    print("You Died", 40, 60, 7)
  end
  
  -- power-up select
  if game_state == "powerup_select" then
    -- draw dark background
    rectfill(20, 25, 108, 95, 1) 
    rect(20, 25, 108, 95, 7)      
    
    -- title
    print("Choose Power-Up", 35, 32, 7)
    
    -- draw power-up options. skip selected power-ups
    local display_row = 0
    for i = 1, max_powerup do
      local powerup_text = powerup_options[i]
      
      -- skip selected power-ups
      if not ((i == 1 and powerup_extra_life) or
              (i == 2 and powerup_increase_speed) or
              (i == 3 and powerup_increase_fire_speed)) then
        display_row = display_row + 1
        local y_pos = 40 + (display_row * 8)
        
        -- draw cursor for selected power-up
        if i == selected_powerup then
          print(">", 30, y_pos, 7)
          print(powerup_text, 38, y_pos, 7)
        else
          print(powerup_text, 38, y_pos, 6)
        end
      end
    end
  end

  -- draw level select overlay
  if game_state == "level_select" then
    -- draw dark background box with border
    rectfill(20, 25, 108, 95, 1)  -- dark blue background
    rect(20, 25, 108, 95, 7)      -- white border
    
    -- title
    print("Select Level", 40, 32, 7)
    
    -- draw level options
    local display_row = 0
    for i = 1, max_level do
      -- skip completed levels
      if not completed_levels[i] then
        display_row = display_row + 1
        local y_pos = 40 + (display_row * 8)
        local level_text = star_systems[i]
        
        -- draw cursor for selected level
        if i == selected_level then
          print(">", 30, y_pos, 7)
          print(level_text, 38, y_pos, 7)  -- highlight selected
        else
          print(level_text, 38, y_pos, 6)  -- normal color
        end
      end
    end
  end
end
__gfx__
00000000000660000000000000000000000000001111111105550000000005500000000000000000000000000000000000000000000000000000000000000000
00000000000660000000000007000000000007001111111105556500000555550000000000000000000000000000000000000000000000000000000000000000
00000000006666000888888000000000007000001111111155555500005555650000000000000000000000000000000000000000000000000000000000000000
00000000006116008888888800000070000000001111111156555550005555550000000000000000000000000000000000000000000000000000000000000000
00000000066116608888888800070000000000001111111155555555055555550000000000000000000000000000000000000000000000000000000000000000
00000000666116660880088000000000000000001111111105555655055555550000000000000000000000000000000000000000000000000000000000000000
00000000006666000088880000000000007000001111111105555550005555000000000000000000000000000000000000000000000000000000000000000000
00000000000660000008800000000000000000701111111100055500000565000000000000000000000000000000000000000000000000000000000000000000
00000000000000001111111100000000000000000000000000555550000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001111111107000000000000000000000000555555555550000000000000000000000000000000000000000000000000000000000000000000
00088000000660001111111100000000000007000777770005555555565555500000000000000000000000000000000000000000000000000000000000000000
00088000000660001881881100000000000000000707070055555555555555500000000000000000000000000000000000000000000000000000000000000000
00088000000660001888881100700000000000000777770055565555555555550000000000000000000000000000000000000000000000000000000000000000
00088000000660001188811100000070000000000777770055555555555555550000000000000000000000000000000000000000000000000000000000000000
00000000000000001118111100000000000000000707070055555555555555550000000000000000000000000000000000000000000000000000000000000000
00000000000000001111111100000000000000000000000005555555005555000000000000000000000000000000000000000000000000000000000000000000
0008800000000000a000a99000000000000000000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008800000000000aaa0a88000000000800000080008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088880000000000a89999a008088080800880080088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00811800000000000998889008888880880880880888888000000000000000000000000000000000000000000000000000000000000000000000000000000000
0881188000000000aa88889988822888888888888822228800000000000000000000000000000000000000000000000000000000000000000000000000000000
88811888000880000a99999a00822800088008800882288000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800000000000a998aa000888800008888000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088000000000000a00a00a00088000000880000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000003000000130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0014000014000000001400000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000014000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000140000130000000000000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000003000000030000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000031300140000000300130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000140000130000000000000000130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0014000004000400000000000000001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000040000040000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050505050505050505050505050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000700001e65020650216502760027600276002760002700025000250002700028000000000000026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000212501b250242002420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000182501e250212500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000700001b6501b6401b6401b6301b6301b6301b6301b6201b6201b6201b6201a6201a6201b6201b6101b6101b6101b6100000000000000000000000000000000000000000000000000000000000000000000000
001000001f1501c14019130171301512013120111200f1200b1200512000120061000410002100011000010003100000000000000000000000000000000000000000000000000000000000000000000000000000
000a00001a5501d550245502455026550295502e55030550245502655029550305502c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c8041f201825018251182211821118211182111821118211181111811118111181111811118111181111811118111181111811118111181111811118111181111871118711187111871118711187111871503700
000e00000be701ae401ae401ae401ae401ae40000000be400be400be400be400be400be400be400be400be40000000be400be400be400be400be400be400be400be400be400be400be400be400be400be400be40
000e000000000000001ce400be40000001ee40000001ae40000001ce400000021e4021e4021e4021e4021e4021e4021e40000001ce400000017e401ee401ee401ee401ee401ee401ee401ee40000001ae5000000
000e00000000000000000000000017e4000000000000000000000000001ae401ae4017e4017e401ae401ae401ae401ae401ae401ae401ae400000000000000001ae40000001ce4017e4021e4000000000001ee40
000e000000000000000000000000000000000000000000000000000000000001ce4000000000001ee400000000000000000000000000000000000000000000000000000000000001ce401ce400000023e4000000
000e00000be4013e4013e4013e4013e4013e400000007e4007e4007e40000001ce400000021e4021e4021e4021e4021e4015e4015e4015e4015e4015e4015e4015e401ae40000001ce401ce401ce401ce401ce40
000e00001ae401ae401ae401ae4007e4007e401ee40000001ae401ae401ae401ae401ae401ae401ae401ae401ae401ae401ae401ce401ce401ce401ce401ce401ce401ce400000009e4009e4009e4009e4009e40
000e00001ee401ee401ee401ee401ee4017e400000013e4021e4021e4021e400000007e4007e4007e4007e4007e4007e40000000000017e401ee40000001ee401ee401ee401ee401ee401ee4010e4010e4000000
000e0000000000be400be400be400be400be400000013e4013e4007e4007e4013e40000001ee4023e4023e4023e4023e4023e4023e4023e4023e4023e4023e4023e400000021e4021e4021e4021e400000000000
000e15001ce4009e4009e4009e40000000be400be400be400be400be400be400be400be400be400be400be400be400be400be400be400be400140001400014000140001400014000140001400014000140001400
000e150023e4023e4023e4023e400000017e4017e4017e4017e4017e4017e400000021e4021e4021e4021e4012e4012e4012e4012e4012e400140001400014000140001400014000140001400014000140001400
000e13000be400be400be4000000000001ee40000001ae40000001ce40000000000017e4017e4017e4017e4017e4017e4017e4001400014000140001400014000140001400014000140001400014000140001400
000e13001ae501ce401ce401ce401ce401ce401ce401ce40000000000000000000001ae400000023e4023e4023e4023e4023e4001400014000140001400014000140001400014000140001400014000140001400
000b0000246501e64017620116201160000000000000000000000000001e20000000000000000000000213000000000000000001d40000000000001c500000000000000000000000000000000000000000000000
001000001805015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d00001875018750187501b7501f75022750227502275024750247501d7001e7002775028750297502975029750297502975029750297500e70022700227002370025700000000000000000000000000000000
__music__
01 0708090a
00 0b0c0d0e
02 0f101112

